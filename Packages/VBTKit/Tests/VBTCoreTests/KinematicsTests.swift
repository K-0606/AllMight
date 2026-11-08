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

    /// 檢查一組合成訊號跑完管線後，每下的 MV 與 ROM 都在 §8 容差內。
    ///
    /// MV < 0.02 m/s、ROM < 1 cm 是 ALGORITHMS §8 的驗收門檻（嚴格）。
    /// PV 是雜訊敏感的 `max(v)`（§6）：σ=2px 時 60fps 約 +13%、30fps 約 +25%
    /// （SG 導數在較大 dt 放大單點雜訊，也是推薦 60fps 的原因，D-016）。§8 未對 PV
    /// 設界，這裡的 `pvTol` 只是寬鬆的正負號／量級合理性檢查，非驗收門檻。
    func assertAccuracy(
        result: SignalGenerator.Result,
        mvTol: Double = 0.02,
        romTol: Double = 0.01,
        pvTol: Double = 0.15
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

    @Test("內部缺漏（= maxGapFrames）經內插後 MV/ROM 仍達標")
    func gapInterpolationEndToEnd() throws {
        var r = SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: 60, geometry: geometry, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 321
        )
        // 把第一下向心中段連續 6 幀（= maxGapFrames）設為低信心（缺漏）。
        for i in 30...35 { r.samples[i].confidence = 0.1 }
        try assertAccuracy(result: r)
    }

    @Test("沒有任何動作：位置幾乎不動、速度接近 0、不崩潰")
    func noMotion() throws {
        let fps = 60.0
        let n = 90
        var rng = SplitMix64(seed: 7)
        let noiseNormY = 2.0 / 1920
        let samples = (0..<n).map { i in
            TrackSample(time: Double(i) / fps, x: 0.5, y: 0.3 + rng.nextGaussian() * noiseNormY, confidence: 0.9)
        }
        let series = try Kinematics.computeSeries(
            samples: samples, selection: selection, geometry: geometry,
            plateDiameterCm: plateDiameterCm, parameters: .standard
        )
        let span = (series.position.max() ?? 0) - (series.position.min() ?? 0)
        #expect(span < 0.02, "靜止時位置帶寬 \(span) m 應很小")
        // 靜止時的速度只剩追蹤雜訊；應低於階段判斷門檻 velThreshold，M4 才不會誤判成動作。
        let meanAbsV = series.velocity.map { abs($0) }.reduce(0, +) / Double(series.velocity.count)
        #expect(meanAbsV < AnalysisParameters.standard.velThreshold, "靜止時平均速度 \(meanAbsV) m/s 應低於門檻")
    }

    @Test("空輸入回傳空序列、不丟錯")
    func emptyInput() throws {
        let series = try Kinematics.computeSeries(
            samples: [], selection: selection, geometry: geometry,
            plateDiameterCm: plateDiameterCm, parameters: .standard
        )
        #expect(series.time.isEmpty)
        #expect(series.velocity.isEmpty)
    }

    @Test("整段都低於 minConfidence 時丟 trackingLost")
    func allBelowConfidence() {
        let fps = 60.0
        let samples = (0..<30).map { i in
            TrackSample(time: Double(i) / fps, x: 0.5, y: 0.3, confidence: 0.1)
        }
        #expect(throws: AnalysisError.self) {
            try Kinematics.computeSeries(
                samples: samples, selection: selection, geometry: geometry,
                plateDiameterCm: plateDiameterCm, parameters: .standard
            )
        }
    }

    @Test("變動影格率（±30% 間隔抖動）重取樣後仍在容差內")
    func variableFrameRate() throws {
        // 以 timeJitter=0.3 產生非等間隔時間戳，解析訊號在真實時間上取值；
        // 管線的 Resampler 應把變動影格率吸收回等間隔網格。
        let r = SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: 60, geometry: geometry, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 999,
            timeJitter: 0.3, jitterSeed: 424242
        )
        try assertAccuracy(result: r)
    }
}
