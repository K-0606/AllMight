import Testing
import Foundation
@testable import VBTCore

/// M3 端對端驗收（docs/ALGORITHMS.md §8）：已知速度函數的合成訊號跑完整運動學管線，
/// 斷言每下向心的 MV 誤差 < 0.02 m/s、ROM 誤差 < 1 cm。
@Suite("運動學管線")
struct KinematicsTests {
    let geometry = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
    let selection = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)
    let plateDiameterCm = 45.0 // 比例尺 0.001 m/px

    /// 由等間隔時間與目標時間取最近的網格索引。
    func nearestIndex(time: [Double], target: Double) -> Int {
        var best = 0
        var bestDiff = Double.greatestFiniteMagnitude
        for (i, t) in time.enumerated() {
            let d = abs(t - target)
            if d < bestDiff { bestDiff = d; best = i }
        }
        return best
    }

    /// 檢查一組合成訊號跑完管線後，每下的 MV 與 ROM 都在容差內。
    func assertAccuracy(
        result: SignalGenerator.Result,
        mvTol: Double = 0.02,
        romTol: Double = 0.01,
        pvTol: Double = 0.05
    ) throws {
        let series = try Kinematics.computeSeries(
            samples: result.samples,
            selection: result.selection,
            geometry: result.geometry,
            plateDiameterCm: result.plateDiameterCm,
            parameters: .standard
        )
        for c in result.concentrics {
            let s = nearestIndex(time: series.time, target: c.startTime)
            let e = nearestIndex(time: series.time, target: c.endTime)
            let dt = series.time[e] - series.time[s]
            let rom = series.position[e] - series.position[s]
            let mv = rom / dt
            let pv = series.velocity[s...e].max() ?? 0
            #expect(abs(mv - c.meanVelocity) < mvTol, "MV \(mv) vs \(c.meanVelocity)")
            #expect(abs(rom - c.rom) < romTol, "ROM \(rom) vs \(c.rom)")
            #expect(abs(pv - c.peakVelocity) < pvTol, "PV \(pv) vs \(c.peakVelocity)")
        }
    }

    @Test("3 下半正弦（60fps、σ=2px）MV 誤差 < 0.02 m/s、ROM < 1 cm")
    func threeRepsAt60fps() throws {
        let r = SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: 60, geometry: geometry, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 20260308
        )
        try assertAccuracy(result: r)
    }

    @Test("30fps 也在容差內")
    func threeRepsAt30fps() throws {
        let geo = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 30)
        let r = SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: 30, geometry: geo, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 77
        )
        try assertAccuracy(result: r)
    }

    @Test("只有 1 下也正確")
    func singleRep() throws {
        let r = SignalGenerator.generate(
            reps: 1, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.35,
            pauseDuration: 0.4, fps: 60, geometry: geometry, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 5
        )
        try assertAccuracy(result: r)
    }

    @Test("變動影格率（抖動時間戳）重取樣後仍在容差內")
    func variableFrameRate() throws {
        // 以 60fps 產生，再抖動時間戳模擬變動影格率（±30% 間隔），重取樣應吸收。
        var r = SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: 60, geometry: geometry, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 999
        )
        var rng = SplitMix64(seed: 424242)
        let base = 1.0 / 60
        var t = 0.0
        var jittered = r.samples
        for i in 0..<jittered.count {
            jittered[i].time = t
            let jitter = base * (0.7 + 0.6 * rng.nextUnit()) // 0.7–1.3 倍間隔
            t += jitter
        }
        r.samples = jittered
        // 時間軸被拉伸，重算每下的時間（以抖動後的時間重新對齊起訖樣本索引）。
        // 用索引對應：合成時第 i 個樣本對應第 i 個抖動時間。
        // 直接用管線輸出的網格與位置斷言 ROM（與時間軸無關），MV 用管線網格時間。
        let series = try Kinematics.computeSeries(
            samples: r.samples, selection: r.selection, geometry: r.geometry,
            plateDiameterCm: r.plateDiameterCm, parameters: .standard
        )
        // ROM 不依賴絕對時間，檢查管線能偵測到 3 段幅度接近 0.127 m 的上升。
        let expectedROM = 2 * 0.4 * 0.5 / Double.pi
        // 掃描速度，找出顯著正向段的位移。
        var roms: [Double] = []
        var i = 0
        let n = series.velocity.count
        while i < n {
            if series.velocity[i] > 0.05 {
                let start = i
                while i < n && series.velocity[i] > 0.05 { i += 1 }
                let end = min(i, n - 1)
                roms.append(series.position[end] - series.position[start])
            } else {
                i += 1
            }
        }
        #expect(roms.count == 3, "偵測到的向心段數 \(roms.count)")
        for rom in roms {
            #expect(abs(rom - expectedROM) < 0.01, "ROM \(rom) vs \(expectedROM)")
        }
    }
}
