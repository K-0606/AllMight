import Foundation
import AVFoundation
import CoreVideo
import CoreMedia
import CoreGraphics

/// 測試用：產生一段「圓盤依已知軌跡移動」的合成影片，並回傳每幀真實中心（見 skill accuracy-check §1）。
///
/// 影片畫一個有對比紋理的槓片（外亮環 + 內色盤 + 中心孔），背景深灰帶雜訊，讓
/// Vision 追蹤有特徵可抓。軌跡由呼叫端以「轉正後影像、原點左上」的像素座標給定。
///
/// - 非旋轉：編碼緩衝即轉正後影像，`preferredTransform` 為單位矩陣，方向 `.up`。
/// - `rotate90`：以橫向緩衝寫入並設 90° transform（方向 `.right`），模擬 iPhone 直拍；
///   轉正後影像仍與非旋轉版相同內容，用來驗證「直拍／橫拍結果一致」。
enum SyntheticPlateVideo {
    struct Result {
        /// 影片檔 URL（呼叫端用完後刪除）。
        let url: URL
        /// 每幀槓片真實中心，轉正後影像、原點左上、像素。
        let centersPx: [CGPoint]
        /// 槓片直徑（轉正後影像像素）。
        let diameterPx: Double
        /// 轉正後寬、高（像素）。
        let orientedWidth: Int
        let orientedHeight: Int
        let fps: Int
    }

    struct GenerationError: Error { let message: String }

    /// 產生一條垂直正弦軌跡（轉正後影像、原點左上）：圓盤在上下 margin 之間平滑來回一個週期。
    /// 水平固定在畫面中線，供追蹤準確度測試使用。
    static func verticalSinusoidCenters(count: Int, width: Int, height: Int, margin: Double) -> [CGPoint] {
        (0..<count).map { i in
            let phase = Double(i) / Double(max(1, count - 1))
            let top = margin
            let bottom = Double(height) - margin
            let y = top + (bottom - top) * (0.5 - 0.5 * cos(2 * .pi * phase))
            return CGPoint(x: Double(width) / 2, y: y)
        }
    }

    static func make(
        orientedWidth: Int,
        orientedHeight: Int,
        centersPx: [CGPoint],
        diameterPx: Double,
        fps: Int,
        rotate90: Bool = false,
        occludedFrames: Set<Int> = []
    ) async throws -> Result {
        // 旋轉版用橫向緩衝；轉正後尺寸維持不變。
        let bufferWidth = rotate90 ? orientedHeight : orientedWidth
        let bufferHeight = rotate90 ? orientedWidth : orientedHeight

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        // 每幀都設為關鍵影格（無跨幀預測）+ 高位元率，避免壓縮把移動圓盤的邊緣抹糊，
        // 讓合成影片的中心位置忠於真實軌跡（追蹤準確度測試需要）。
        let pixelCount = bufferWidth * bufferHeight
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: bufferWidth,
            AVVideoHeightKey: bufferHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: pixelCount * 12,
                AVVideoMaxKeyFrameIntervalKey: 1,
                AVVideoAllowFrameReorderingKey: false,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        input.transform = rotate90 ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: bufferWidth,
                kCVPixelBufferHeightKey as String: bufferHeight,
            ]
        )
        guard writer.canAdd(input) else { throw GenerationError(message: "無法加入 writer input") }
        writer.add(input)
        guard writer.startWriting() else {
            throw GenerationError(message: "startWriting 失敗：\(String(describing: writer.error))")
        }
        writer.startSession(atSourceTime: .zero)

        let timescale = CMTimeScale(fps)
        var rng = SplitMix64(seed: 0xA11_6E7)
        // 固定一組背景雜訊點，所有影格共用，避免逐幀閃爍干擾追蹤。
        let noise = makeNoise(count: 400, width: bufferWidth, height: bufferHeight, rng: &rng)

        for (frameIndex, orientedCenter) in centersPx.enumerated() {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            guard let buffer = adaptor.pixelBufferPool.flatMap({ pool -> CVPixelBuffer? in
                var pb: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb)
                return pb
            }) else {
                throw GenerationError(message: "無法從 pool 建立 pixel buffer")
            }
            let bufferCenter = bufferCenter(
                orientedCenter: orientedCenter,
                orientedWidth: orientedWidth,
                rotate90: rotate90
            )
            draw(
                into: buffer,
                bufferWidth: bufferWidth,
                bufferHeight: bufferHeight,
                center: bufferCenter,
                diameter: diameterPx,
                noise: noise,
                occluded: occludedFrames.contains(frameIndex)
            )
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: timescale)
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw GenerationError(message: "append 影格失敗：\(String(describing: writer.error))")
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw GenerationError(message: "finishWriting 失敗：\(String(describing: writer.error))")
        }
        return Result(
            url: url,
            centersPx: centersPx,
            diameterPx: diameterPx,
            orientedWidth: orientedWidth,
            orientedHeight: orientedHeight,
            fps: fps
        )
    }

    /// 轉正後中心（原點左上）→ 編碼緩衝中心（原點左上）。
    ///
    /// 旋轉版模擬 `.right`（iPhone 直拍）：Vision 以 `.right` 會把緩衝順時針轉 90° 才解讀，
    /// 故緩衝點 (xb, yb) 對應轉正點 (W_o − yb, xb)。反解得 xb = yo、yb = W_o − xo。
    private static func bufferCenter(
        orientedCenter: CGPoint,
        orientedWidth: Int,
        rotate90: Bool
    ) -> CGPoint {
        guard rotate90 else { return orientedCenter }
        return CGPoint(x: orientedCenter.y, y: Double(orientedWidth) - orientedCenter.x)
    }

    private static func makeNoise(count: Int, width: Int, height: Int, rng: inout SplitMix64) -> [CGRect] {
        (0..<count).map { _ in
            let x = Double(rng.next() % UInt64(width))
            let y = Double(rng.next() % UInt64(height))
            let size = 2.0 + Double(rng.next() % 4)
            return CGRect(x: x, y: y, width: size, height: size)
        }
    }

    /// 以 CoreGraphics 畫入 BGRA 緩衝。座標採原點左上（先翻轉 CG 的預設底部原點）。
    private static func draw(
        into buffer: CVPixelBuffer,
        bufferWidth: Int,
        bufferHeight: Int,
        center: CGPoint,
        diameter: Double,
        noise: [CGRect],
        occluded: Bool
    ) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: base,
            width: bufferWidth,
            height: bufferHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        // 以原點左上作圖：翻轉 y。
        ctx.translateBy(x: 0, y: CGFloat(bufferHeight))
        ctx.scaleBy(x: 1, y: -1)

        // 背景深灰 + 固定雜訊。
        ctx.setFillColor(CGColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: bufferWidth, height: bufferHeight))
        ctx.setFillColor(CGColor(red: 0.28, green: 0.28, blue: 0.30, alpha: 1))
        for rect in noise { ctx.fill(rect) }

        if occluded {
            // 用與背景相近的大矩形蓋住整個槓片活動範圍，模擬被身體擋住。
            ctx.setFillColor(CGColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1))
            ctx.fill(CGRect(
                x: center.x - diameter, y: center.y - diameter,
                width: diameter * 2, height: diameter * 2
            ))
            return
        }

        let radius = diameter / 2
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: diameter, height: diameter)
        // 外亮環。
        ctx.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1))
        ctx.fillEllipse(in: rect)
        // 內色盤。
        ctx.setFillColor(CGColor(red: 0.85, green: 0.25, blue: 0.15, alpha: 1))
        ctx.fillEllipse(in: rect.insetBy(dx: diameter * 0.18, dy: diameter * 0.18))
        // 中心孔。
        ctx.setFillColor(CGColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1))
        ctx.fillEllipse(in: rect.insetBy(dx: diameter * 0.40, dy: diameter * 0.40))
    }
}

/// 決定性亂數（SplitMix64），讓合成影片可重現（見 .claude/rules/testing.md）。
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
