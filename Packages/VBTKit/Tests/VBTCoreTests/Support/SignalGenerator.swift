import Foundation
@testable import VBTCore

/// 合成運動訊號產生器（測試用，skill velocity-analysis §1、docs/ALGORITHMS.md §8）。
///
/// 以半正弦速度剖面產生「向心上升 + 離心下降 + 停頓」的多下動作，換算成 Vision 正規化
/// 座標並加上高斯雜訊（σ 以像素計、固定種子可重現）。回傳 `TrackSample[]` 與真實值
/// （每下的 MV、PV、ROM、起訖時間），供端對端管線測試斷言。
///
/// 半正弦速度 `v(τ) = Vpeak·sin(π τ / T)`：位移 `= 2·Vpeak·T / π`、`MV = 2·Vpeak / π`。
/// 離心峰值 `Ve = Vc·Tc / Te` 使每下回到起點（位移相消）。
enum SignalGenerator {
    struct Concentric {
        var startTime: Double
        var endTime: Double
        var meanVelocity: Double
        var peakVelocity: Double
        var rom: Double
    }

    struct Result {
        var samples: [TrackSample]
        var concentrics: [Concentric]
        var selection: PlateSelection
        var geometry: VideoGeometry
        var plateDiameterCm: Double
    }

    static func generate(
        reps: Int,
        concentricDuration Tc: Double,
        eccentricDuration Te: Double,
        peakVelocity Vc: Double,
        pauseDuration: Double,
        fps: Double,
        geometry: VideoGeometry,
        selection: PlateSelection,
        plateDiameterCm: Double,
        noiseSigmaPx: Double,
        seed: UInt64,
        baseNormalizedY: Double = 0.3,
        timeJitter: Double = 0,
        jitterSeed: UInt64 = 1
    ) -> Result {
        let Ve = Tc > 0 && Te > 0 ? Vc * Tc / Te : 0

        // 建立時間軸片段：起始停頓，接著每下（向心、離心、停頓）。
        enum Kind { case pause, concentric, eccentric }
        var segments: [(start: Double, duration: Double, kind: Kind, basePos: Double)] = []
        var cursor = 0.0
        var pos = 0.0
        func push(_ kind: Kind, _ dur: Double) {
            segments.append((cursor, dur, kind, pos))
            switch kind {
            case .pause: break
            case .concentric: pos += 2 * Vc * Tc / Double.pi
            case .eccentric: pos -= 2 * Ve * Te / Double.pi
            }
            cursor += dur
        }
        push(.pause, pauseDuration)
        var concentrics: [Concentric] = []
        for _ in 0..<reps {
            let cStart = cursor
            concentrics.append(Concentric(
                startTime: cStart,
                endTime: cStart + Tc,
                meanVelocity: 2 * Vc / Double.pi,
                peakVelocity: Vc,
                rom: 2 * Vc * Tc / Double.pi
            ))
            push(.concentric, Tc)
            push(.eccentric, Te)
            push(.pause, pauseDuration)
        }
        let total = cursor

        // 位置（公尺）解析式：定位 t 落在哪個片段再加局部位移。
        func positionMeters(_ t: Double) -> Double {
            for seg in segments where t >= seg.start && t <= seg.start + seg.duration + 1e-12 {
                let tau = t - seg.start
                switch seg.kind {
                case .pause:
                    return seg.basePos
                case .concentric:
                    return seg.basePos + (Vc * Tc / Double.pi) * (1 - cos(Double.pi * tau / Tc))
                case .eccentric:
                    return seg.basePos - (Ve * Te / Double.pi) * (1 - cos(Double.pi * tau / Te))
                }
            }
            return segments.last.map { $0.basePos } ?? 0
        }

        // 正規化換算：y_m = (yN − y0N)·heightPx·scale ⇒ yN = y0N + y_m / (heightPx·scale)。
        let scale = Calibrator.scale(plateDiameterCm: plateDiameterCm, selection: selection)
        let metersPerNormY = Double(geometry.heightPx) * scale
        let noiseNormY = noiseSigmaPx / Double(geometry.heightPx)
        let noiseNormX = noiseSigmaPx / Double(geometry.widthPx)

        // 取樣時間：等間隔，或以 timeJitter 抖動間隔模擬變動影格率（間隔落在 [1−j, 1+j]/fps）。
        var times: [Double] = []
        if timeJitter <= 0 {
            let count = Int((total * fps).rounded(.down)) + 1
            times = (0..<count).map { Double($0) / fps }
        } else {
            var jr = SplitMix64(seed: jitterSeed)
            var t = 0.0
            while t <= total {
                times.append(t)
                let factor = 1 - timeJitter + 2 * timeJitter * jr.nextUnit()
                t += factor / fps
            }
        }

        var rng = SplitMix64(seed: seed)
        var samples: [TrackSample] = []
        samples.reserveCapacity(times.count)
        for t in times {
            let yN = baseNormalizedY + positionMeters(t) / metersPerNormY + rng.nextGaussian() * noiseNormY
            let xN = 0.5 + rng.nextGaussian() * noiseNormX
            samples.append(TrackSample(time: t, x: xN, y: yN, confidence: 0.95))
        }

        return Result(
            samples: samples,
            concentrics: concentrics,
            selection: selection,
            geometry: geometry,
            plateDiameterCm: plateDiameterCm
        )
    }
}

/// 固定種子的亂數產生器（SplitMix64），讓合成雜訊可重現（.claude/rules/testing.md）。
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// 均勻分布 [0, 1)。
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    /// 標準常態分布（Box-Muller）。
    mutating func nextGaussian() -> Double {
        let u1 = max(nextUnit(), 1e-12)
        let u2 = nextUnit()
        return (-2 * Foundation.log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }
}
