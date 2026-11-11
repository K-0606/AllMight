import Foundation
import Observation
import VBTCore
import VBTVision

/// 分析中頁的狀態：消費 `AnalysisPipeline` 的 `AsyncThrowingStream`，把進度轉成畫面狀態。
///
/// 重運算都在 `AnalysisPipeline` actor；本型別只在 `@MainActor` 上搬運 `Sendable` 值。
/// 取消由 `.task` 隨畫面消失自動觸發（見 ARCHITECTURE §5）：Task 取消 → stream `onTermination`
/// → 追蹤每幀 `checkCancellation` 停止。
@MainActor
@Observable
final class AnalysisModel {
    enum State: Equatable {
        /// 追蹤中；`fraction` 為 0…1 的進度。
        case tracking(fraction: Double)
        /// 追蹤完成，計算運動學與指標中。
        case analyzing
        /// 完成，附帶結果與原始追蹤樣本（樣本供存檔與升級重算，見 DECISIONS D-030）。
        case finished(SetAnalysis, samples: [TrackSample])
        /// 失敗，附帶錯誤（App 層對應成 PRD §3.6 文字）。
        case failed(AnalysisError)
    }

    private(set) var state: State = .tracking(fraction: 0)

    private let url: URL
    private let trimStartSeconds: Double
    private let trimEndSeconds: Double
    private let selection: PlateSelection
    private let exercise: Exercise
    private let plateDiameterCm: Double
    private let pipeline = AnalysisPipeline()

    init(
        clip: VideoClip,
        trimStartSeconds: Double,
        trimEndSeconds: Double,
        selection: PlateSelection,
        exercise: Exercise,
        plateDiameterCm: Double
    ) {
        self.url = clip.url
        self.trimStartSeconds = trimStartSeconds
        self.trimEndSeconds = trimEndSeconds
        self.selection = selection
        self.exercise = exercise
        self.plateDiameterCm = plateDiameterCm
    }

    /// 跑分析並隨進度更新 `state`。由 `.task` 呼叫，離開畫面即取消。
    func run() async {
        do {
            let stream = await pipeline.analyze(
                url: url,
                trimStartSeconds: trimStartSeconds,
                trimEndSeconds: trimEndSeconds,
                selection: selection,
                exercise: exercise,
                plateDiameterCm: plateDiameterCm
            )
            for try await progress in stream {
                switch progress {
                case .tracking(let fraction):
                    state = .tracking(fraction: fraction)
                case .analyzing:
                    state = .analyzing
                case .finished(let analysis, let samples):
                    state = .finished(analysis, samples: samples)
                }
            }
        } catch is CancellationError {
            // 使用者取消或離開畫面：不顯示錯誤。
        } catch let error as AnalysisError {
            state = .failed(error)
        } catch {
            state = .failed(.videoUnreadable)
        }
    }
}
