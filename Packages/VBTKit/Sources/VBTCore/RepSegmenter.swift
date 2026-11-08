import Foundation

/// 一下（rep）切分後的相位配對：必有向心，視動作順序可能帶一個離心。
public struct SegmentedRep: Sendable, Equatable {
    /// 向心相位。
    public var concentric: Phase
    /// 配對到的離心相位（若有）。
    public var eccentric: Phase?

    public init(concentric: Phase, eccentric: Phase?) {
        self.concentric = concentric
        self.eccentric = eccentric
    }
}

/// 把等間隔運動學序列切成一下下動作（docs/ALGORITHMS.md §5）。純函式，可在 macOS `swift test`。
///
/// 先找「核心」：速度連續 ≥ `minPhaseSeconds` 超過 `velThreshold` 的區段（向心正向、離心負向，去抖）。
/// 再把核心向外延伸到位置的轉折點（局部極值＝速度跨 0 的那一點），讓位移與時間完整（§5）；
/// 這比直接用速度跨 0 更穩，因為極值附近速度接近 0、雜訊會左右正負號。
/// 有效向心需位移 ≥ `minROM`；依 `Exercise.startsWithConcentric` 把向心與相鄰離心配對
/// （硬舉配之後、蹲／臥配之前）。無對應向心的離心（例如最後放下槓鈴）不算一下。
public enum RepSegmenter {
    public static func segment(
        series: KinematicSeries,
        exercise: Exercise,
        parameters: AnalysisParameters
    ) -> [SegmentedRep] {
        let v = series.velocity
        let p = series.position
        let t = series.time
        let n = v.count
        guard n > 0, series.dt > 0 else { return [] }

        let fps = 1.0 / series.dt
        let minPhaseFrames = max(1, Int((parameters.minPhaseSeconds * fps).rounded()))
        let vth = parameters.velThreshold

        // 1. 找核心：連續 ≥ minPhaseFrames 個樣本超過門檻的區段。
        var cores: [(kind: PhaseKind, a: Int, b: Int)] = []
        for positive in [true, false] {
            var k = 0
            while k < n {
                let over = positive ? v[k] > vth : v[k] < -vth
                if !over { k += 1; continue }
                var j = k
                while j + 1 < n && (positive ? v[j + 1] > vth : v[j + 1] < -vth) { j += 1 }
                if j - k + 1 >= minPhaseFrames {
                    cores.append((positive ? .concentric : .eccentric, k, j))
                }
                k = j + 1
            }
        }
        cores.sort { $0.a < $1.a }

        // 2. 每個核心向外延伸到位置轉折點（§5：讓位移與時間完整）。延伸範圍以最近的「反向」核心
        //    為界（而非任何相鄰核心），這樣同一次向心被卡點切成兩個核心時能各自延伸到相同的底與頂，
        //    之後再去除重複；真正分開的兩下之間位置會轉折，延伸會自然停住而保持分開。
        var phases: [Phase] = []
        for (idx, c) in cores.enumerated() {
            var lo = 0
            var i = idx - 1
            while i >= 0 { if cores[i].kind != c.kind { lo = cores[i].b; break }; i -= 1 }
            var hi = n - 1
            var j = idx + 1
            while j < cores.count { if cores[j].kind != c.kind { hi = cores[j].a; break }; j += 1 }

            let ascending = c.kind == .concentric
            let s = walkBack(p, from: c.a, limit: lo, ascending: ascending)
            let e = walkForward(p, from: c.b, limit: hi, ascending: ascending)
            let phase = Phase(kind: c.kind, startIndex: s, endIndex: e, startTime: t[s], endTime: t[e])
            // 去重：卡點切成的同類核心延伸後範圍相同，只保留一個。
            if phases.last != phase { phases.append(phase) }
        }

        // 3. 配對（ALGORITHMS §5）。只有位移 ≥ minROM 的向心才算有效。
        var reps: [SegmentedRep] = []
        var k = 0
        while k < phases.count {
            let ph = phases[k]
            if ph.kind == .concentric, p[ph.endIndex] - p[ph.startIndex] >= parameters.minROM {
                var eccentric: Phase?
                if exercise.startsWithConcentric {
                    // 硬舉：向心 + 之後緊接的離心。
                    if k + 1 < phases.count, phases[k + 1].kind == .eccentric {
                        eccentric = phases[k + 1]
                        k += 1
                    }
                } else {
                    // 蹲、臥推：向心 + 之前緊接的離心。
                    if k - 1 >= 0, phases[k - 1].kind == .eccentric {
                        eccentric = phases[k - 1]
                    }
                }
                reps.append(SegmentedRep(concentric: ph, eccentric: eccentric))
            }
            k += 1
        }
        return reps
    }

    /// 由核心起點往回走到位置轉折點：向心走到局部最小（底），離心走到局部最大（頂）。
    private static func walkBack(_ p: [Double], from a: Int, limit lo: Int, ascending: Bool) -> Int {
        var s = a
        while s > lo && (ascending ? p[s - 1] < p[s] : p[s - 1] > p[s]) { s -= 1 }
        return s
    }

    /// 由核心終點往前走到位置轉折點：向心走到局部最大（頂），離心走到局部最小（底）。
    private static func walkForward(_ p: [Double], from b: Int, limit hi: Int, ascending: Bool) -> Int {
        var e = b
        while e < hi && (ascending ? p[e + 1] > p[e] : p[e + 1] < p[e]) { e += 1 }
        return e
    }
}
