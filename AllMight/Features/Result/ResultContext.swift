import Foundation
import VBTCore

/// 結果頁所需的一切：分析結果、顯示摘要用的設定值、以及重播片段與畫軌跡所需的來源。
///
/// M5 僅在記憶體中傳遞，不持久化（儲存為 M6）。作為導覽路由值需 `Hashable`；
/// 內含的 `SetAnalysis` 不是 `Hashable`，故以 `id` 作識別。
struct ResultContext: Hashable, Identifiable {
    let id: UUID
    let analysis: SetAnalysis
    let clip: VideoClip
    let trimStartSeconds: Double
    let trimEndSeconds: Double
    let selection: PlateSelection
    let exercise: Exercise
    let loadKg: Double
    let rpe: Double?
    let isWarmup: Bool

    init(
        analysis: SetAnalysis,
        clip: VideoClip,
        trimStartSeconds: Double,
        trimEndSeconds: Double,
        selection: PlateSelection,
        exercise: Exercise,
        loadKg: Double,
        rpe: Double?,
        isWarmup: Bool
    ) {
        self.id = UUID()
        self.analysis = analysis
        self.clip = clip
        self.trimStartSeconds = trimStartSeconds
        self.trimEndSeconds = trimEndSeconds
        self.selection = selection
        self.exercise = exercise
        self.loadKg = loadKg
        self.rpe = rpe
        self.isWarmup = isWarmup
    }

    static func == (lhs: ResultContext, rhs: ResultContext) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 分析成功後、選 RPE 之前的暫存資料（給 RPE sheet 用）。選完 RPE 即組成 `ResultContext`。
struct PendingAnalysis: Identifiable {
    let id = UUID()
    let analysis: SetAnalysis
    let clip: VideoClip
    let trimStartSeconds: Double
    let trimEndSeconds: Double
    let selection: PlateSelection
    let exercise: Exercise
    let loadKg: Double
}
