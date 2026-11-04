import Foundation
import SwiftData

/// 一組訓練的分析結果。欄位定義見 `docs/ARCHITECTURE.md §4.2`。
///
/// 資料庫只存**檔名**（`videoFileName`、`samplesFileName`），實際路徑一律透過 `FileStore` 取得，
/// 因為 App 容器的絕對路徑會變（見 rule `privacy-and-files`）。
/// 原始 `TrackSample[]` 另存檔，改重量／RPE 或演算法升級時不用重新追蹤。
@Model
final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// `Exercise` 的 raw value（字串），避免 enum 遷移問題。
    var exerciseRaw: String
    var loadKg: Double
    var plateDiameterCm: Double
    /// nil 代表使用者跳過 RPE。
    var rpe: Double?
    var isWarmup: Bool
    /// Application Support/Videos/ 底下的檔名。
    var videoFileName: String
    /// 片段起點（秒，相對影片起點）。
    var trimStart: Double
    /// 片段終點（秒，相對影片起點）。
    var trimEnd: Double
    /// `PlateSelection` 的 JSON。
    var selectionData: Data
    /// `VideoGeometry` 的 JSON。
    var geometryData: Data
    /// Application Support/Samples/ 底下的檔名（`TrackSample[]` 的 JSON）。
    var samplesFileName: String
    /// `SetAnalysis` 的 JSON。
    var analysisData: Data

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        exerciseRaw: String,
        loadKg: Double,
        plateDiameterCm: Double,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        videoFileName: String,
        trimStart: Double,
        trimEnd: Double,
        selectionData: Data,
        geometryData: Data,
        samplesFileName: String,
        analysisData: Data
    ) {
        self.id = id
        self.createdAt = createdAt
        self.exerciseRaw = exerciseRaw
        self.loadKg = loadKg
        self.plateDiameterCm = plateDiameterCm
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.videoFileName = videoFileName
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.selectionData = selectionData
        self.geometryData = geometryData
        self.samplesFileName = samplesFileName
        self.analysisData = analysisData
    }
}
