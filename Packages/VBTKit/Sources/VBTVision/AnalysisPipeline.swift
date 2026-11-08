import Foundation
import os
import VBTCore

/// 串起完整分析：`TrackingRunner`（追蹤）→ `Kinematics` → `RepSegmenter` → `MetricsCalculator`
/// → `SetAnalysis`（見 docs/ARCHITECTURE.md §3、§5）。
///
/// 以 `AsyncThrowingStream<AnalysisProgress>` 回報進度並附帶最終結果；支援取消：消費端停止疊代
/// （break 或取消疊代的 Task）會觸發 `onTermination`，取消內部工作，追蹤迴圈每幀的
/// `Task.checkCancellation()` 隨即停止。Vision／AVFoundation 只在 `TrackingRunner` 內使用。
public actor AnalysisPipeline {
    private static let logger = Logger(subsystem: "com.kun0606.AllMight", category: "Analysis")

    public init() {}

    public func analyze(
        url: URL,
        trimStartSeconds: Double,
        trimEndSeconds: Double,
        selection: PlateSelection,
        exercise: Exercise,
        plateDiameterCm: Double,
        parameters: AnalysisParameters = .standard
    ) -> AsyncThrowingStream<AnalysisProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let analysis = try await self.runPipeline(
                        url: url,
                        trimStartSeconds: trimStartSeconds,
                        trimEndSeconds: trimEndSeconds,
                        selection: selection,
                        exercise: exercise,
                        plateDiameterCm: plateDiameterCm,
                        parameters: parameters,
                        continuation: continuation
                    )
                    continuation.yield(.finished(analysis))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runPipeline(
        url: URL,
        trimStartSeconds: Double,
        trimEndSeconds: Double,
        selection: PlateSelection,
        exercise: Exercise,
        plateDiameterCm: Double,
        parameters: AnalysisParameters,
        continuation: AsyncThrowingStream<AnalysisProgress, Error>.Continuation
    ) async throws -> SetAnalysis {
        // 1. 追蹤（重用 M2.5 的 TrackingRunner，見 D-025），逐幀回報進度。
        let run = try await TrackingRunner().run(
            url: url,
            trimStartSeconds: trimStartSeconds,
            trimEndSeconds: trimEndSeconds,
            selection: selection,
            parameters: parameters
        ) { fraction in
            continuation.yield(.tracking(fraction: fraction))
        }
        try Task.checkCancellation()
        if let lost = run.lostAtTime {
            throw AnalysisError.trackingLost(atTime: lost)
        }

        // 2. VBTCore：運動學 → 次數切分 → 指標。
        continuation.yield(.analyzing)
        let series = try Kinematics.computeSeries(
            samples: run.samples,
            selection: selection,
            geometry: run.geometry,
            plateDiameterCm: plateDiameterCm,
            parameters: parameters
        )
        let reps = RepSegmenter.segment(series: series, exercise: exercise, parameters: parameters)
        guard !reps.isEmpty else { throw AnalysisError.noRepsDetected }
        let (repMetrics, summary) = MetricsCalculator.metrics(for: reps, series: series)

        Self.logger.info("分析完成 次數=\(summary.repCount, privacy: .public) 平均速度=\(summary.meanVelocity, privacy: .public)m/s")

        return SetAnalysis(
            analysisVersion: VBTCore.analysisVersion,
            parameters: parameters,
            reps: repMetrics,
            summary: summary,
            series: series
        )
    }
}
