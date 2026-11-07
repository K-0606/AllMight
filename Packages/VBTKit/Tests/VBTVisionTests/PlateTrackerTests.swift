import Testing
import Foundation
import CoreGraphics
import VBTCore
@testable import VBTVision

/// PlateTracker 的單元測試：初始框換算與遺失判斷（見 skill plate-tracking §1、§3）。
@Suite("PlateTracker")
struct PlateTrackerTests {
    @Test("初始框以圓心為中心、邊長 = 直徑，換成 Vision 正規化")
    func initialBoundingBox() {
        let geometry = VideoGeometry(widthPx: 1000, heightPx: 2000, nominalFPS: 60)
        let selection = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 200)
        let box = PlateTracker.initialBoundingBox(selection: selection, geometry: geometry)
        // 200px / 1000 寬 = 0.2；200px / 2000 高 = 0.1。
        #expect(abs(box.width - 0.2) < 1e-9)
        #expect(abs(box.height - 0.1) < 1e-9)
        #expect(abs(box.midX - 0.5) < 1e-9)
        #expect(abs(box.midY - 0.5) < 1e-9)
    }

    @Test("靠邊的圓心，初始框被夾在 0–1 內")
    func initialBoundingBoxClamped() {
        let geometry = VideoGeometry(widthPx: 1000, heightPx: 1000, nominalFPS: 60)
        let selection = PlateSelection(centerX: 0.02, centerY: 0.98, diameterPx: 200)
        let box = PlateTracker.initialBoundingBox(selection: selection, geometry: geometry)
        #expect(box.minX >= 0)
        #expect(box.minY >= 0)
        #expect(box.maxX <= 1 + 1e-9)
        #expect(box.maxY <= 1 + 1e-9)
    }

    @Test("槓片被長時間擋住時丟出 trackingLost，時間落在擋住區間內")
    func occlusionThrowsTrackingLost() async throws {
        let width = 360, height = 640, fps = 60
        let frameCount = 120
        let centers = SyntheticPlateVideo.verticalSinusoidCenters(
            count: frameCount, width: width, height: height, margin: 120
        )
        // 從第 40 幀起連續擋住 20 幀，遠超過 maxGapFrames（6）。
        let occludedRange = 40..<60
        let video = try await SyntheticPlateVideo.make(
            orientedWidth: width, orientedHeight: height,
            centersPx: centers, diameterPx: 110, fps: fps,
            occludedFrames: Set(occludedRange)
        )
        defer { try? FileManager.default.removeItem(at: video.url) }

        let reader = try await FrameReader(url: video.url, trimStartSeconds: 0, trimEndSeconds: 2)
        let selection = PlateSelection(
            centerX: centers[0].x / Double(width),
            centerY: 1 - centers[0].y / Double(height),
            diameterPx: 110
        )
        let tracker = PlateTracker(selection: selection, geometry: reader.geometry)

        var thrownTime: Double?
        do {
            while let frame = try reader.next() {
                _ = try tracker.track(frame)
            }
        } catch let AnalysisError.trackingLost(atTime: time) {
            thrownTime = time
        }

        let time = try #require(thrownTime, "擋住後應丟出 trackingLost")
        // 擋住從第 40 幀（≈0.667s）開始；trackingLost 應在擋住開始後、片段結束前。
        #expect(time >= Double(occludedRange.lowerBound) / Double(fps) - 2.0 / Double(fps))
        #expect(time <= 2.0)
    }

    @Test("連續缺漏剛好 = maxGapFrames 不丟；再多 1 幀丟 trackingLost（ALGORITHMS §8 邊界）")
    func missGapBoundary() async throws {
        let width = 360, height = 640, fps = 60, frameCount = 30
        // 槓片靜止：遮擋幀數 = 連續缺漏數（重現時位置不變，不會多出瞬移缺漏）。
        let center = CGPoint(x: Double(width) / 2, y: Double(height) / 2)
        let centers = Array(repeating: center, count: frameCount)
        var parameters = AnalysisParameters.standard
        parameters.maxGapFrames = 4
        let selection = PlateSelection(
            centerX: center.x / Double(width),
            centerY: 1 - center.y / Double(height),
            diameterPx: 110
        )
        let duration = Double(frameCount) / Double(fps) + 0.2

        func runTracking(occludedCount: Int) async throws {
            let video = try await SyntheticPlateVideo.make(
                orientedWidth: width, orientedHeight: height,
                centersPx: centers, diameterPx: 110, fps: fps,
                occludedFrames: Set(10..<(10 + occludedCount))
            )
            defer { try? FileManager.default.removeItem(at: video.url) }
            let reader = try await FrameReader(url: video.url, trimStartSeconds: 0, trimEndSeconds: duration)
            let tracker = PlateTracker(selection: selection, geometry: reader.geometry, parameters: parameters)
            while let frame = try reader.next() {
                _ = try tracker.track(frame)
            }
        }

        // 剛好 maxGapFrames（4）幀缺漏：不應丟（若丟，下行會把錯誤往外拋，測試失敗）。
        try await runTracking(occludedCount: parameters.maxGapFrames)

        // maxGapFrames + 1（5）幀缺漏：應丟 trackingLost。
        var threw = false
        do {
            try await runTracking(occludedCount: parameters.maxGapFrames + 1)
        } catch let AnalysisError.trackingLost(atTime: _) {
            threw = true
        }
        #expect(threw, "超過 maxGapFrames 的連續缺漏應丟 trackingLost")
    }
}
