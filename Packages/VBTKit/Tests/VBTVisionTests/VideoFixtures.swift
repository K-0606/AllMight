import Foundation
import AVFoundation
import CoreVideo
import CoreMedia

/// 測試用：用 AVAssetWriter 在暫存資料夾產生一段純色影片（見 skill video-pipeline §4）。
///
/// 可指定編碼尺寸、影格數、fps 與 `preferredTransform`（模擬直拍／橫拍）。
/// 回傳的 URL 由呼叫端在用完後刪除。
enum VideoFixtures {
    struct FixtureError: Error { let message: String }

    static func makeVideo(
        width: Int,
        height: Int,
        frameCount: Int,
        fps: Int,
        transform: CGAffineTransform
    ) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        input.transform = transform
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: nil
        )
        guard writer.canAdd(input) else { throw FixtureError(message: "無法加入 writer input") }
        writer.add(input)
        guard writer.startWriting() else {
            throw FixtureError(message: "startWriting 失敗：\(String(describing: writer.error))")
        }
        writer.startSession(atSourceTime: .zero)

        let timescale = CMTimeScale(fps)
        for frameIndex in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            guard let buffer = makePixelBuffer(width: width, height: height) else {
                throw FixtureError(message: "無法建立 pixel buffer")
            }
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: timescale)
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw FixtureError(message: "append 影格失敗：\(String(describing: writer.error))")
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw FixtureError(message: "finishWriting 失敗：\(String(describing: writer.error))")
        }
        return url
    }

    private static func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32ARGB, attributes as CFDictionary, &pixelBuffer
        )
        guard let buffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 128, CVPixelBufferGetBytesPerRow(buffer) * height)
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
