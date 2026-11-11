import Foundation
import Testing
import SwiftData
import VBTCore
@testable import AllMight

/// M6 儲存／刪除／升級重算的檔案系統與資料庫驗收（ROADMAP M6、DECISIONS D-030）。
///
/// 用記憶體 `ModelContainer`，但 `FileStore` 寫的是真實 Application Support；每個測試自行清掉檔案。
/// `WorkoutStore` 在 App 預設 MainActor 隔離下為 MainActor-isolated，故測試標 `@MainActor`。
@MainActor
struct WorkoutStoreTests {

    /// 乾淨的 N 下向心+離心半正弦垂直軌跡（Vision 正規化 y），clean signal 必能切出 N 下。
    /// 公式與 VBTCore 的 SignalGenerator 一致（概念相同、無雜訊）。
    static func motionSamples(reps: Int) -> [TrackSample] {
        let fps = 60.0, Tc = 0.5, Te = 0.6, pause = 0.4, Vc = 0.4
        let Ve = Vc * Tc / Te
        let mPerNorm = 1920.0 * 0.001 // heightPx × scale（diameterPx 450、45cm → 0.001 m/px）
        let y0 = 0.3

        enum Kind { case pause, concentric, eccentric }
        var segments: [(start: Double, duration: Double, kind: Kind, basePos: Double)] = []
        var cursor = 0.0, pos = 0.0
        func push(_ kind: Kind, _ dur: Double) {
            segments.append((cursor, dur, kind, pos))
            switch kind {
            case .pause: break
            case .concentric: pos += 2 * Vc * Tc / .pi
            case .eccentric: pos -= 2 * Ve * Te / .pi
            }
            cursor += dur
        }
        push(.pause, pause)
        for _ in 0..<reps { push(.concentric, Tc); push(.eccentric, Te); push(.pause, pause) }
        let total = cursor

        func positionMeters(_ t: Double) -> Double {
            for seg in segments where t >= seg.start && t <= seg.start + seg.duration + 1e-12 {
                let tau = t - seg.start
                switch seg.kind {
                case .pause: return seg.basePos
                case .concentric: return seg.basePos + (Vc * Tc / .pi) * (1 - cos(.pi * tau / Tc))
                case .eccentric: return seg.basePos - (Ve * Te / .pi) * (1 - cos(.pi * tau / Te))
                }
            }
            return segments.last?.basePos ?? 0
        }

        let count = Int((total * fps).rounded(.down)) + 1
        return (0..<count).map { i in
            let t = Double(i) / fps
            return TrackSample(time: t, x: 0.5, y: y0 + positionMeters(t) / mPerNorm, confidence: 0.95)
        }
    }

    static let geometry = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
    static let selection = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)

    func makeStore() throws -> WorkoutStore {
        let container = try ModelContainer(
            for: WorkoutSet.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return WorkoutStore(modelContext: ModelContext(container))
    }

    func analysis(reps: Int) throws -> (analysis: SetAnalysis, samples: [TrackSample]) {
        let samples = Self.motionSamples(reps: reps)
        let analysis = try SetAnalyzer.analyze(
            samples: samples, selection: Self.selection, geometry: Self.geometry,
            plateDiameterCm: 45, exercise: .conventionalDeadlift
        )
        return (analysis, samples)
    }

    @Test("存檔建立 WorkoutSet 與樣本檔")
    func saveCreatesRecordAndSamplesFile() throws {
        let store = try makeStore()
        let (analysis, samples) = try analysis(reps: 2)

        let set = try store.save(
            analysis: analysis, samples: samples, videoFileName: "\(UUID().uuidString).mov",
            geometry: Self.geometry, selection: Self.selection, trimStartSeconds: 0, trimEndSeconds: 4,
            exercise: .conventionalDeadlift, loadKg: 100, plateDiameterCm: 45, rpe: 8, isWarmup: false
        )
        defer { try? store.delete(set) }

        let samplesURL = try store.fileStore.url(for: .samples, fileName: set.samplesFileName)
        #expect(FileManager.default.fileExists(atPath: samplesURL.path))

        let fetched = try store.modelContext.fetch(FetchDescriptor<WorkoutSet>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.loadKg == 100)
    }

    @Test("刪除連同影片與樣本檔一起消失（檢查檔案系統）")
    func deleteRemovesFiles() throws {
        let store = try makeStore()
        let (analysis, samples) = try analysis(reps: 2)

        // 先放一個假的影片檔，模擬匯入時已存進 Videos/。
        let videoFileName = "\(UUID().uuidString).mov"
        try store.fileStore.write(.videos, data: Data([0x00, 0x01]), fileName: videoFileName)

        let set = try store.save(
            analysis: analysis, samples: samples, videoFileName: videoFileName,
            geometry: Self.geometry, selection: Self.selection, trimStartSeconds: 0, trimEndSeconds: 4,
            exercise: .conventionalDeadlift, loadKg: 100, plateDiameterCm: 45, rpe: nil, isWarmup: false
        )
        let videoURL = try store.fileStore.url(for: .videos, fileName: videoFileName)
        let samplesURL = try store.fileStore.url(for: .samples, fileName: set.samplesFileName)
        #expect(FileManager.default.fileExists(atPath: videoURL.path))
        #expect(FileManager.default.fileExists(atPath: samplesURL.path))

        try store.delete(set)

        #expect(!FileManager.default.fileExists(atPath: videoURL.path))
        #expect(!FileManager.default.fileExists(atPath: samplesURL.path))
        #expect(try store.modelContext.fetch(FetchDescriptor<WorkoutSet>()).isEmpty)
    }

    @Test("編輯重量/RPE 只改中繼資料、不動分析")
    func updateMetadataKeepsAnalysis() throws {
        let store = try makeStore()
        let (analysis, samples) = try analysis(reps: 2)
        let set = try store.save(
            analysis: analysis, samples: samples, videoFileName: "\(UUID().uuidString).mov",
            geometry: Self.geometry, selection: Self.selection, trimStartSeconds: 0, trimEndSeconds: 4,
            exercise: .conventionalDeadlift, loadKg: 100, plateDiameterCm: 45, rpe: 8, isWarmup: false
        )
        defer { try? store.delete(set) }
        let before = set.analysisData

        try store.updateMetadata(set, loadKg: 120, rpe: 9, isWarmup: false)

        #expect(set.loadKg == 120)
        #expect(set.rpe == 9)
        #expect(set.analysisData == before, "編輯重量/RPE 不應改變分析資料")
    }

    @Test("analysisVersion 較舊時用樣本重算並寫回目前版本")
    func recomputeUpgradesStaleRecord() throws {
        let store = try makeStore()
        let (fresh, samples) = try analysis(reps: 2)
        // 人為做一筆「舊版本」紀錄（analysisVersion = 目前 − 1）。
        let stale = SetAnalysis(
            analysisVersion: VBTCore.analysisVersion - 1,
            parameters: fresh.parameters, reps: fresh.reps, summary: fresh.summary, series: fresh.series
        )
        let set = try store.save(
            analysis: stale, samples: samples, videoFileName: "\(UUID().uuidString).mov",
            geometry: Self.geometry, selection: Self.selection, trimStartSeconds: 0, trimEndSeconds: 4,
            exercise: .conventionalDeadlift, loadKg: 100, plateDiameterCm: 45, rpe: 8, isWarmup: false
        )
        defer { try? store.delete(set) }

        let changed = try store.recomputeIfNeeded(set)
        #expect(changed)

        let reloaded = try JSONDecoder().decode(SetAnalysis.self, from: set.analysisData)
        #expect(reloaded.analysisVersion == VBTCore.analysisVersion)
        #expect(reloaded.summary.repCount == 2)

        // 已是目前版本：再呼叫不應重算。
        #expect(try store.recomputeIfNeeded(set) == false)
    }
}
