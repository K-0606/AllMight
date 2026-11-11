import Foundation
import SwiftData
import VBTCore

/// 寫入與維護 `WorkoutSet` 紀錄的本機操作：存檔、刪除（連同影片與樣本檔）、編輯中繼資料、
/// 以及 `analysisVersion` 升級時用存好的樣本重算（見 docs/ARCHITECTURE.md §4.2、DECISIONS D-030）。
///
/// 資料庫只存檔名，所有路徑一律透過 `FileStore`（見 rule `privacy-and-files`）。
/// 不是 `Sendable`：持有 `ModelContext`，只在建立它的 isolation（App 為 `@MainActor`；測試為其自身 context）內使用。
struct WorkoutStore {
    let modelContext: ModelContext
    var fileStore = FileStore()

    private var encoder: JSONEncoder { JSONEncoder() }
    private var decoder: JSONDecoder { JSONDecoder() }

    /// 分析完成後自動存一組紀錄：先寫樣本檔，再插入 `WorkoutSet` 並存檔。回傳建立的紀錄。
    @discardableResult
    func save(
        analysis: SetAnalysis,
        samples: [TrackSample],
        videoFileName: String,
        geometry: VideoGeometry,
        selection: PlateSelection,
        trimStartSeconds: Double,
        trimEndSeconds: Double,
        exercise: Exercise,
        loadKg: Double,
        plateDiameterCm: Double,
        rpe: Double?,
        isWarmup: Bool
    ) throws -> WorkoutSet {
        let id = UUID()
        let samplesFileName = "\(id.uuidString).json"
        try fileStore.write(.samples, data: try encoder.encode(samples), fileName: samplesFileName)

        let set = WorkoutSet(
            id: id,
            exerciseRaw: exercise.rawValue,
            loadKg: loadKg,
            plateDiameterCm: plateDiameterCm,
            rpe: rpe,
            isWarmup: isWarmup,
            videoFileName: videoFileName,
            trimStart: trimStartSeconds,
            trimEnd: trimEndSeconds,
            selectionData: try encoder.encode(selection),
            geometryData: try encoder.encode(geometry),
            samplesFileName: samplesFileName,
            analysisData: try encoder.encode(analysis)
        )
        modelContext.insert(set)
        do {
            try modelContext.save()
        } catch {
            // 資料庫寫入失敗：清掉剛寫的樣本檔，避免留下無紀錄指向的孤兒檔。
            try? fileStore.delete(.samples, fileName: samplesFileName)
            throw error
        }
        return set
    }

    /// 刪除一組紀錄，連同影片與樣本檔（rule `privacy-and-files`：刪紀錄要一併刪檔）。
    func delete(_ set: WorkoutSet) throws {
        try fileStore.deleteFiles(videoFileName: set.videoFileName, samplesFileName: set.samplesFileName)
        modelContext.delete(set)
        try modelContext.save()
    }

    /// 編輯重量與 RPE（中繼資料，不影響分析數值，故不重算；見 DECISIONS D-030）。
    func updateMetadata(_ set: WorkoutSet, loadKg: Double, rpe: Double?, isWarmup: Bool) throws {
        set.loadKg = loadKg
        set.rpe = rpe
        set.isWarmup = isWarmup
        try modelContext.save()
    }

    /// 若紀錄的 `analysisVersion` 比目前舊，就用存好的樣本重算並寫回（不重新追蹤）。
    /// 回傳是否有重算。缺樣本檔或動作無法解析時不重算、回傳 false。
    @discardableResult
    func recomputeIfNeeded(_ set: WorkoutSet) throws -> Bool {
        let analysis = try decoder.decode(SetAnalysis.self, from: set.analysisData)
        guard analysis.analysisVersion < VBTCore.analysisVersion else { return false }
        guard let exercise = Exercise(rawValue: set.exerciseRaw) else { return false }

        let samples = try decoder.decode([TrackSample].self, from: fileStore.read(.samples, fileName: set.samplesFileName))
        let selection = try decoder.decode(PlateSelection.self, from: set.selectionData)
        let geometry = try decoder.decode(VideoGeometry.self, from: set.geometryData)

        let updated = try SetAnalyzer.analyze(
            samples: samples,
            selection: selection,
            geometry: geometry,
            plateDiameterCm: set.plateDiameterCm,
            exercise: exercise
        )
        set.analysisData = try encoder.encode(updated)
        try modelContext.save()
        return true
    }
}
