import Testing
import Foundation
import CoreGraphics
import VBTCore
@testable import VBTVision

/// AnalysisPipeline 端對端（docs/ARCHITECTURE.md §3、§5）：合成影片 → 真實 Vision 追蹤 →
/// 運動學 → 次數切分 → 指標。驗證次數正確、進度回報、取消可快速停止。
@Suite("AnalysisPipeline")
struct AnalysisPipelineTests {
    /// 產生 `reps` 次上下動作的垂直軌跡（轉正後影像、原點左上）。
    /// 每下一個餘弦週期：由底（原點左上的大 y）上升到頂再回到底 → 向心在前（硬舉順序）。
    static func multiRepCenters(
        reps: Int, framesPerRep: Int, width: Int, height: Int, margin: Double
    ) -> [CGPoint] {
        let top = margin
        let bottom = Double(height) - margin
        return (0..<reps * framesPerRep).map { i in
            let phase = Double(i % framesPerRep) / Double(framesPerRep)
            let y = bottom - (bottom - top) * (0.5 - 0.5 * cos(2 * .pi * phase))
            return CGPoint(x: Double(width) / 2, y: y)
        }
    }

    static func makeVideo(reps: Int, framesPerRep: Int = 60) async throws -> SyntheticPlateVideo.Result {
        let width = 360, height = 640, fps = 60
        let centers = multiRepCenters(
            reps: reps, framesPerRep: framesPerRep, width: width, height: height, margin: 220
        )
        return try await SyntheticPlateVideo.make(
            orientedWidth: width, orientedHeight: height,
            centersPx: centers, diameterPx: 110, fps: fps
        )
    }

    static func selection(for video: SyntheticPlateVideo.Result) -> PlateSelection {
        let c0 = video.centersPx[0]
        return PlateSelection(
            centerX: c0.x / Double(video.orientedWidth),
            centerY: 1 - c0.y / Double(video.orientedHeight),
            diameterPx: video.diameterPx
        )
    }

    @Test("3 下合成影片：端對端次數正確、摘要合理")
    func threeRepsEndToEnd() async throws {
        let video = try await Self.makeVideo(reps: 3)
        defer { try? FileManager.default.removeItem(at: video.url) }

        let stream = await AnalysisPipeline().analyze(
            url: video.url,
            trimStartSeconds: 0,
            trimEndSeconds: Double(video.centersPx.count) / Double(video.fps) + 0.2,
            selection: Self.selection(for: video),
            exercise: .conventionalDeadlift,
            plateDiameterCm: 45,
            parameters: .standard
        )

        var analysis: SetAnalysis?
        for try await progress in stream {
            if case let .finished(result) = progress { analysis = result }
        }
        let result = try #require(analysis, "應回報 finished 結果")
        #expect(result.summary.repCount == 3)
        #expect(result.reps.count == 3)
        #expect(result.summary.meanVelocity > 0)
        #expect(result.summary.meanROM > 0.10)
        #expect(result.analysisVersion == VBTCore.analysisVersion)
    }

    @Test("進度回報：先 tracking（遞增 0…1）再 analyzing，最後 finished")
    func progressReporting() async throws {
        let video = try await Self.makeVideo(reps: 2)
        defer { try? FileManager.default.removeItem(at: video.url) }

        let stream = await AnalysisPipeline().analyze(
            url: video.url,
            trimStartSeconds: 0,
            trimEndSeconds: Double(video.centersPx.count) / Double(video.fps) + 0.2,
            selection: Self.selection(for: video),
            exercise: .conventionalDeadlift,
            plateDiameterCm: 45
        )

        var trackingFractions: [Double] = []
        var sawAnalyzing = false
        var sawFinished = false
        for try await progress in stream {
            switch progress {
            case let .tracking(fraction):
                #expect(fraction >= 0 && fraction <= 1)
                #expect(!sawAnalyzing && !sawFinished, "tracking 應在 analyzing/finished 之前")
                trackingFractions.append(fraction)
            case .analyzing:
                #expect(!sawFinished, "analyzing 應在 finished 之前")
                sawAnalyzing = true
            case .finished:
                sawFinished = true
            }
        }
        #expect(!trackingFractions.isEmpty)
        #expect(trackingFractions == trackingFractions.sorted(), "追蹤進度應不遞減")
        #expect(sawAnalyzing)
        #expect(sawFinished)
    }

    @Test("取消：消費端取消後 0.5 秒內停止")
    func cancellationStopsQuickly() async throws {
        // 長一點的影片，確保取消時追蹤仍在進行。
        let video = try await Self.makeVideo(reps: 6)
        defer { try? FileManager.default.removeItem(at: video.url) }

        let stream = await AnalysisPipeline().analyze(
            url: video.url,
            trimStartSeconds: 0,
            trimEndSeconds: Double(video.centersPx.count) / Double(video.fps) + 0.2,
            selection: Self.selection(for: video),
            exercise: .conventionalDeadlift,
            plateDiameterCm: 45
        )

        let consumer = Task {
            for try await _ in stream {}
        }
        // 等追蹤開始，再取消消費端 → 觸發 onTermination → 取消內部工作。
        try await Task.sleep(nanoseconds: 100_000_000)
        let start = Date()
        consumer.cancel()
        _ = try? await consumer.value
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 0.5, "取消後應在 0.5 秒內停止，實際 \(elapsed)s")
    }
}
