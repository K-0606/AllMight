import Foundation
import VBTCore

/// 結果頁所需的一切：分析結果、重播片段與畫軌跡所需的來源（影片 URL + 幾何）、以及顯示摘要用的設定值。
///
/// 「新分析」與「歷史重看」共用同一結果頁：前者分析完成後組成，後者由 `WorkoutSet` 解碼組成
/// （見 DECISIONS D-030）。不再依賴 `VideoClip`／`VideoInfo`；歷史只需 `videoFileName`（→FileStore URL）
/// 與 `geometryData`（→`VideoGeometry`）。
///
/// 作為導覽路由值需 `Hashable`；內含的 `SetAnalysis` 不是 `Hashable`，故以 `id` 作識別。
struct ResultContext: Hashable, Identifiable {
    let id: UUID
    /// 已存紀錄的 `WorkoutSet.id`；新分析存檔後帶入，供結果頁編輯重量/RPE。nil 代表尚未存檔。
    let recordID: UUID?
    let analysis: SetAnalysis
    /// 影片本機 URL（Application Support/Videos/）。
    let videoURL: URL
    /// 轉正後影片幾何，畫軌跡線用。
    let geometry: VideoGeometry
    let trimStartSeconds: Double
    let trimEndSeconds: Double
    let selection: PlateSelection
    let exercise: Exercise
    let loadKg: Double
    let rpe: Double?
    let isWarmup: Bool

    init(
        recordID: UUID?,
        analysis: SetAnalysis,
        videoURL: URL,
        geometry: VideoGeometry,
        trimStartSeconds: Double,
        trimEndSeconds: Double,
        selection: PlateSelection,
        exercise: Exercise,
        loadKg: Double,
        rpe: Double?,
        isWarmup: Bool
    ) {
        self.id = recordID ?? UUID()
        self.recordID = recordID
        self.analysis = analysis
        self.videoURL = videoURL
        self.geometry = geometry
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

extension ResultContext {
    enum DecodeError: Error { case unknownExercise }

    /// 由已存的 `WorkoutSet` 解碼組成（歷史重看）。影片 URL 與樣本路徑一律經 `FileStore`。
    init(set: WorkoutSet, fileStore: FileStore) throws {
        let decoder = JSONDecoder()
        guard let exercise = Exercise(rawValue: set.exerciseRaw) else { throw DecodeError.unknownExercise }
        self.init(
            recordID: set.id,
            analysis: try decoder.decode(SetAnalysis.self, from: set.analysisData),
            videoURL: try fileStore.url(for: .videos, fileName: set.videoFileName),
            geometry: try decoder.decode(VideoGeometry.self, from: set.geometryData),
            trimStartSeconds: set.trimStart,
            trimEndSeconds: set.trimEnd,
            selection: try decoder.decode(PlateSelection.self, from: set.selectionData),
            exercise: exercise,
            loadKg: set.loadKg,
            rpe: set.rpe,
            isWarmup: set.isWarmup
        )
    }
}

/// 分析成功後、選 RPE 之前的暫存資料（給 RPE sheet 用）。選完 RPE 即存檔並組成 `ResultContext`。
struct PendingAnalysis: Identifiable {
    let id = UUID()
    let analysis: SetAnalysis
    /// 原始追蹤樣本，供存檔與日後升級重算（不重新追蹤，見 DECISIONS D-007、D-030）。
    let samples: [TrackSample]
    let videoURL: URL
    let geometry: VideoGeometry
    let trimStartSeconds: Double
    let trimEndSeconds: Double
    let selection: PlateSelection
    let exercise: Exercise
    let loadKg: Double
    let plateDiameterCm: Double
}
