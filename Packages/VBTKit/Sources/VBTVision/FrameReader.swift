import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import ImageIO
import VBTCore

/// 從影片片段逐幀讀出的單一影格：來源方向的像素緩衝 + 時間 + 方向。
///
/// `pixelBuffer` 未轉正（未套用 preferredTransform）；交給 Vision 時用 `orientation` 轉正，
/// 所有座標因此落在「轉正後影像」的 Vision 正規化空間（見 docs/ALGORITHMS.md §0）。
/// `time` 為秒，相對片段起點（presentation time − trimStart）。
///
/// 非 `Sendable`：由 `FrameReader` 產生後在同一 context 立即消費，不跨 actor 傳遞
/// （見 docs/ARCHITECTURE.md §5、DECISIONS D-021）。內部保留來源 `CMSampleBuffer`
/// 以固定 `pixelBuffer` 的記憶體生命週期（`alwaysCopiesSampleData = false`，緩衝記憶體由 sample 擁有）。
struct Frame {
    /// 來源方向的像素緩衝（8-bit 4:2:0）。
    let pixelBuffer: CVPixelBuffer
    /// 相對片段起點的時間（秒）。
    let time: Double
    /// 轉正用的方向，交給 Vision。
    let orientation: CGImagePropertyOrientation
    /// 保留來源 sample 以固定 `pixelBuffer` 的記憶體生命週期；不直接讀取。
    private let sampleBuffer: CMSampleBuffer

    fileprivate init(
        pixelBuffer: CVPixelBuffer,
        time: Double,
        orientation: CGImagePropertyOrientation,
        sampleBuffer: CMSampleBuffer
    ) {
        self.pixelBuffer = pixelBuffer
        self.time = time
        self.orientation = orientation
        self.sampleBuffer = sampleBuffer
    }
}

/// 逐幀讀取影片片段，輸出 8-bit 像素緩衝供 Vision 追蹤（見 skill video-pipeline §2）。
///
/// 採**拉取式**（`next()` 一次一幀）而非 `AsyncThrowingStream`：解碼本身是同步的，
/// 拉取式可避免預先緩衝整段影片造成記憶體爆量，也不會丟幀（見 DECISIONS D-021）。
/// 整個生命週期留在單一 context（未來的 `AnalysisPipeline` actor）內，`Frame` 不跨 actor 傳遞。
///
/// 8-bit 輸出格式 `kCVPixelFormatType_420YpCbCr8BiPlanarFullRange` 讓解碼器自動把 10-bit HDR
/// 降成 8-bit 給 Vision；追蹤不看顏色，HDR 不影響結果（見 DECISIONS D-018/D-019/D-020）。
final class FrameReader {
    /// 來源影片的顯示方向（由 preferredTransform 推導）。
    let orientation: VideoOrientation
    /// 轉正後的幾何資訊（尺寸、標稱 fps）。
    let geometry: VideoGeometry

    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private let trimStartSeconds: Double
    private var didStart = false

    /// 建立讀取器，只讀 `trimStartSeconds`…`trimEndSeconds`（秒，相對整段影片）。
    ///
    /// 不重做匯入檢查（那是 `VideoInspector` 的責任）；讀不到影像軌道時丟 `videoUnreadable`。
    init(url: URL, trimStartSeconds: Double, trimEndSeconds: Double) async throws {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw AnalysisError.videoUnreadable
        }
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let fps = Double(try await track.load(.nominalFrameRate))

        self.orientation = VideoOrientation.from(transform: transform)
        let orientedRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        self.geometry = VideoGeometry(
            widthPx: Int(abs(orientedRect.width).rounded()),
            heightPx: Int(abs(orientedRect.height).rounded()),
            nominalFPS: fps
        )

        let reader = try AVAssetReader(asset: asset)
        let start = CMTime(seconds: max(0, trimStartSeconds), preferredTimescale: 600)
        let duration = CMTime(seconds: max(0, trimEndSeconds - trimStartSeconds), preferredTimescale: 600)
        reader.timeRange = CMTimeRange(start: start, duration: duration)

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AnalysisError.videoUnreadable }
        reader.add(output)

        self.reader = reader
        self.output = output
        self.trimStartSeconds = trimStartSeconds
    }

    /// 取下一幀；片段讀完回傳 `nil`，讀取失敗丟 `videoUnreadable`。
    func next() throws -> Frame? {
        if !didStart {
            guard reader.startReading() else { throw AnalysisError.videoUnreadable }
            didStart = true
        }
        while let sample = output.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            let presentationSeconds = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            return Frame(
                pixelBuffer: pixelBuffer,
                time: presentationSeconds - trimStartSeconds,
                orientation: orientation.cg,
                sampleBuffer: sample
            )
        }
        if reader.status == .failed { throw AnalysisError.videoUnreadable }
        return nil
    }

    /// 取消讀取（取消工作時呼叫）。
    func cancel() {
        reader.cancelReading()
    }
}
