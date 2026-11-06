import Testing
import Foundation
import CoreGraphics
import VBTCore
@testable import VBTVision

@Test("橫拍 60fps 影片：尺寸、方向、長度正確，非低影格率")
func inspectLandscapeVideo() async throws {
    let url = try await VideoFixtures.makeVideo(
        width: 160, height: 90, frameCount: 72, fps: 60, transform: .identity
    )
    defer { try? FileManager.default.removeItem(at: url) }

    let info = try await VideoInspector.inspect(url: url)
    #expect(info.orientation == .up)
    #expect(info.geometry.widthPx == 160)
    #expect(info.geometry.heightPx == 90)
    #expect(abs(info.durationSeconds - 1.2) < 0.15)
    #expect(abs(info.geometry.nominalFPS - 60) < 5)
    #expect(!info.isLowFrameRate)
    #expect(info.codec == "avc1")
    #expect(!info.isHDR)
}

@Test("直拍 30fps 影片：轉正後尺寸交換、方向 .right、標記為低影格率")
func inspectPortraitVideo() async throws {
    let url = try await VideoFixtures.makeVideo(
        width: 160, height: 90, frameCount: 36, fps: 30,
        transform: CGAffineTransform(rotationAngle: .pi / 2)
    )
    defer { try? FileManager.default.removeItem(at: url) }

    let info = try await VideoInspector.inspect(url: url)
    #expect(info.orientation == .right)
    #expect(info.geometry.widthPx == 90)
    #expect(info.geometry.heightPx == 160)
    #expect(abs(info.durationSeconds - 1.2) < 0.15)
    #expect(info.isLowFrameRate)
}

@Test("太短的影片被阻擋")
func inspectTooShortVideo() async throws {
    let url = try await VideoFixtures.makeVideo(
        width: 160, height: 90, frameCount: 15, fps: 60, transform: .identity
    )
    defer { try? FileManager.default.removeItem(at: url) }

    do {
        _ = try await VideoInspector.inspect(url: url)
        Issue.record("預期丟出 videoTooShort，但沒有丟出錯誤")
    } catch let error as AnalysisError {
        guard case .videoTooShort = error else {
            Issue.record("預期 videoTooShort，實際為 \(error)")
            return
        }
    }
}
