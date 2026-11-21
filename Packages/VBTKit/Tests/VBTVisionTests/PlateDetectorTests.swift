import Testing
import Foundation
import CoreGraphics
import VBTCore
@testable import VBTVision

/// PlateDetector（Core ML）整合 smoke 測試（docs/ALGORITHMS.md §9、DECISIONS D-033）。
///
/// 驗證「打包的模型載入 + Vision 推論 + 回 `[DetectedPlate]`」整條 Swift 路徑在 macOS 上能跑、不丟錯、
/// 座標落在合理範圍。合成圓環未必被真實槓片模型偵測到，故不斷言「一定有偵測」——
/// 真實影片偵測準確度由使用者實機目視（D-019、D-033）。
@Suite("槓片偵測模型")
struct PlateDetectorTests {
    @Test("模型載入並在一幀上推論：不丟錯、回陣列、框座標與信心在合理範圍")
    func modelLoadsAndRuns() async throws {
        let width = 720, height = 1280
        let centers = Array(repeating: CGPoint(x: 360, y: 420), count: 3)
        let video = try await SyntheticPlateVideo.make(
            orientedWidth: width, orientedHeight: height,
            centersPx: centers, diameterPx: 240, fps: 30
        )
        defer { try? FileManager.default.removeItem(at: video.url) }

        let plates = try await PlateDetector().detect(url: video.url, atSeconds: 0)

        // smoke：載入+推論成功即算過（合成環未必被偵測）。若有偵測，座標/信心需在合理範圍。
        for p in plates {
            #expect(p.confidence >= 0 && p.confidence <= 1)
            #expect(p.centerX >= 0 && p.centerX <= 1)
            #expect(p.centerY >= 0 && p.centerY <= 1)
            #expect(p.width > 0 && p.width <= 1)
            #expect(p.height > 0 && p.height <= 1)
        }
        // 回傳依信心遞減排序。
        #expect(plates == plates.sorted { $0.confidence > $1.confidence })
    }

    @Test("讀不到幀（atSeconds 超過片長）→ 回空陣列、不丟錯")
    func noFrameReturnsEmpty() async throws {
        let video = try await SyntheticPlateVideo.make(
            orientedWidth: 320, orientedHeight: 568,
            centersPx: Array(repeating: CGPoint(x: 160, y: 284), count: 3), diameterPx: 100, fps: 30
        )
        defer { try? FileManager.default.removeItem(at: video.url) }
        // 片長約 0.1 秒；atSeconds 10 的視窗內無可解碼幀 → []。
        let plates = try await PlateDetector().detect(url: video.url, atSeconds: 10)
        #expect(plates.isEmpty)
    }

    /// 真實影片（`TestVideos/`，gitignore，不在就跳過）：驗證 Swift/Vision 的座標/方向映射正確。
    /// 以 `SDL1r260`（硬舉起點、槓片在畫面**左下**）為準——y 翻轉會讓 centerY 跑到上半，x 翻轉跑到右側，皆會被抓出。
    /// 以測試原始檔位置回推 repo 根目錄（與 cwd 無關）：
    /// `.../AllMight/Packages/VBTKit/Tests/VBTVisionTests/PlateDetectorTests.swift` → 往上 5 層 = repo 根。
    static let sdlVideoPath: String = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("TestVideos/SDL1r260.mov").path
    }()
    static var hasSDLVideo: Bool { FileManager.default.fileExists(atPath: sdlVideoPath) }

    @Test("真實硬舉影片：偵測到槓片且座標落在左下（座標/方向無翻轉）", .enabled(if: hasSDLVideo))
    func detectsRealDeadliftPlate() async throws {
        let url = URL(fileURLWithPath: Self.sdlVideoPath)
        let plates = try await PlateDetector().detect(url: url, atSeconds: 1.5)
        let best = try #require(plates.first, "硬舉起點幀應偵測到槓片")
        // Python 參考：px 中心約 (290,1299)/1080×1920 → Vision 正規化 centerX≈0.27、centerY≈0.32（原點左下）。
        #expect(best.confidence > 0.4)
        #expect(best.centerX > 0.12 && best.centerX < 0.45) // 左側（x 翻轉會 >0.5）
        #expect(best.centerY > 0.15 && best.centerY < 0.50) // 下半（y 翻轉會 >0.5）
        #expect(best.width > 0.1 && best.height > 0.1)
    }
}
