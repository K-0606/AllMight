import Testing
import Foundation
import CoreGraphics
@testable import VBTVision

/// FrameReader 的單元測試（見 skill video-pipeline §2、§4）：
/// 片段範圍內幀數、時間戳遞增、方向與轉正尺寸。
@Suite("FrameReader")
struct FrameReaderTests {
    /// 產生一段等間隔上下移動的合成影片，供讀取測試使用。
    private func makeVideo(
        width: Int = 240,
        height: Int = 320,
        frameCount: Int,
        fps: Int,
        rotate90: Bool = false
    ) async throws -> SyntheticPlateVideo.Result {
        let centers = (0..<frameCount).map { i -> CGPoint in
            let t = Double(i) / Double(max(1, frameCount - 1))
            let y = 80 + (Double(height) - 160) * (0.5 - 0.5 * cos(2 * .pi * t))
            return CGPoint(x: Double(width) / 2, y: y)
        }
        return try await SyntheticPlateVideo.make(
            orientedWidth: width, orientedHeight: height,
            centersPx: centers, diameterPx: 70, fps: fps, rotate90: rotate90
        )
    }

    @Test("讀出的幀數約等於片段時長 × fps")
    func frameCountMatchesClip() async throws {
        let fps = 30
        let video = try await makeVideo(frameCount: 60, fps: fps) // 2 秒
        defer { try? FileManager.default.removeItem(at: video.url) }

        let reader = try await FrameReader(url: video.url, trimStartSeconds: 0, trimEndSeconds: 2)
        var count = 0
        while try reader.next() != nil { count += 1 }
        #expect(abs(count - 60) <= 1)
    }

    @Test("時間戳從 0 起遞增")
    func timestampsIncreaseFromZero() async throws {
        let video = try await makeVideo(frameCount: 60, fps: 30)
        defer { try? FileManager.default.removeItem(at: video.url) }

        let reader = try await FrameReader(url: video.url, trimStartSeconds: 0, trimEndSeconds: 2)
        var times: [Double] = []
        while let frame = try reader.next() { times.append(frame.time) }

        let first = try #require(times.first)
        #expect(first >= 0)
        #expect(first < 1.0 / 30 + 1e-6)
        for (a, b) in zip(times, times.dropFirst()) {
            #expect(b > a)
        }
    }

    @Test("片段範圍只讀出子區間的幀，時間相對片段起點")
    func trimRangeLimitsFrames() async throws {
        let fps = 30
        let video = try await makeVideo(frameCount: 90, fps: fps) // 3 秒
        defer { try? FileManager.default.removeItem(at: video.url) }

        let reader = try await FrameReader(url: video.url, trimStartSeconds: 1.0, trimEndSeconds: 2.0)
        var times: [Double] = []
        while let frame = try reader.next() { times.append(frame.time) }

        #expect(abs(times.count - fps) <= 2) // 約 1 秒 × 30fps
        let first = try #require(times.first)
        #expect(first < 2.0 / Double(fps)) // 第一幀時間接近 0（已扣掉 trimStart）
    }

    @Test("橫拍（非旋轉）影片方向為 .up，轉正尺寸不變")
    func landscapeOrientationUp() async throws {
        let video = try await makeVideo(width: 320, height: 240, frameCount: 30, fps: 30)
        defer { try? FileManager.default.removeItem(at: video.url) }

        let reader = try await FrameReader(url: video.url, trimStartSeconds: 0, trimEndSeconds: 1)
        #expect(reader.orientation == .up)
        #expect(reader.geometry.widthPx == 320)
        #expect(reader.geometry.heightPx == 240)
    }

    @Test("直拍（90° transform）影片方向為 .right，轉正尺寸為直式")
    func portraitOrientationRight() async throws {
        let video = try await makeVideo(width: 240, height: 320, frameCount: 30, fps: 30, rotate90: true)
        defer { try? FileManager.default.removeItem(at: video.url) }

        let reader = try await FrameReader(url: video.url, trimStartSeconds: 0, trimEndSeconds: 1)
        #expect(reader.orientation == .right)
        // 轉正後維持 240×320（直式）。
        #expect(reader.geometry.widthPx == 240)
        #expect(reader.geometry.heightPx == 320)
    }
}
