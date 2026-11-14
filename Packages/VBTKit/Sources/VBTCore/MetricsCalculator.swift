import Foundation

/// 由切分好的相位計算每下指標與組別摘要（docs/ALGORITHMS.md §6）。純函式。
///
/// 向心指標以帶號位移計（向上為正）；離心指標取絕對值。MPV 的推進段以重力門檻界定。
public enum MetricsCalculator {
    /// 重力加速度量級（m/s²）；MPV 推進段結束於 PV 之後第一個 `a < −gravity` 的前一點（§6）。
    private static let gravity = 9.81

    public static func metrics(
        for reps: [SegmentedRep],
        series: KinematicSeries
    ) -> (reps: [RepMetrics], summary: SetSummary) {
        let p = series.position
        let v = series.velocity
        let a = series.acceleration
        let t = series.time

        var out: [RepMetrics] = []
        for (i, rep) in reps.enumerated() {
            let concentric = phaseMetrics(rep.concentric, p: p, v: v, t: t, absolute: false)
            let eccentric = rep.eccentric.map { phaseMetrics($0, p: p, v: v, t: t, absolute: true) }
            let mpv = computeMPV(rep.concentric, p: p, v: v, a: a, t: t)
            out.append(RepMetrics(
                index: i + 1, concentric: concentric, eccentric: eccentric,
                mpv: mpv, restAfter: nil, dropFromFirst: nil
            ))
        }

        // restAfter：下一下第一個階段起點 − 這一下最後一個階段終點。
        for i in out.indices where i + 1 < out.count {
            let thisEnd = lastEndTime(reps[i])
            let nextStart = firstStartTime(reps[i + 1])
            out[i].restAfter = nextStart - thisEnd
        }

        // 相對第 1 下（以向心 MV）。
        if let mv1 = out.first?.concentric.meanVelocity, mv1 != 0 {
            for i in out.indices where i > 0 {
                out[i].dropFromFirst = (out[i].concentric.meanVelocity - mv1) / mv1
            }
        }

        return (out, summary(out))
    }

    private static func phaseMetrics(
        _ phase: Phase, p: [Double], v: [Double], t: [Double], absolute: Bool
    ) -> PhaseMetrics {
        let s = phase.startIndex
        let e = phase.endIndex
        let duration = t[e] - t[s]
        let rawDisplacement = p[e] - p[s]
        let displacement = absolute ? abs(rawDisplacement) : rawDisplacement
        let meanVelocity = duration > 0 ? displacement / duration : 0
        let peak = absolute
            ? (v[s...e].map { abs($0) }.max() ?? 0)
            : (v[s...e].max() ?? 0)
        return PhaseMetrics(
            duration: duration, meanVelocity: meanVelocity,
            peakVelocity: peak, displacement: displacement,
            startTime: phase.startTime, endTime: phase.endTime
        )
    }

    // ALGORITHMS §6 MPV：推進段 [s, k]，k = PV 之後第一個 a < −gravity 的前一點；無則 k = e。
    private static func computeMPV(
        _ phase: Phase, p: [Double], v: [Double], a: [Double], t: [Double]
    ) -> Double {
        let s = phase.startIndex
        let e = phase.endIndex
        var pvIndex = s
        var pvValue = v[s]
        for k in s...e where v[k] > pvValue {
            pvValue = v[k]
            pvIndex = k
        }
        var k = e
        if pvIndex < e {
            for j in (pvIndex + 1)...e where a[j] < -gravity {
                k = j - 1
                break
            }
        }
        let duration = t[k] - t[s]
        if duration > 0 { return (p[k] - p[s]) / duration }
        // k 緊接 s（推進段過短）時退回整段向心平均速度，避免除以 0。
        let full = t[e] - t[s]
        return full > 0 ? (p[e] - p[s]) / full : 0
    }

    private static func lastEndTime(_ rep: SegmentedRep) -> Double {
        max(rep.concentric.endTime, rep.eccentric?.endTime ?? rep.concentric.endTime)
    }

    private static func firstStartTime(_ rep: SegmentedRep) -> Double {
        min(rep.concentric.startTime, rep.eccentric?.startTime ?? rep.concentric.startTime)
    }

    private static func summary(_ reps: [RepMetrics]) -> SetSummary {
        let count = reps.count
        guard count > 0 else {
            return SetSummary(repCount: 0, meanVelocity: 0, peakVelocity: 0, meanROM: 0, velocityLoss: nil)
        }
        let mvs = reps.map { $0.concentric.meanVelocity }
        let roms = reps.map { $0.concentric.displacement }
        let meanVelocity = mvs.reduce(0, +) / Double(count)
        let peakVelocity = reps.map { $0.concentric.peakVelocity }.max() ?? 0
        let meanROM = roms.reduce(0, +) / Double(count)
        var velocityLoss: Double?
        if count >= 2, let first = mvs.first, let last = mvs.last, first != 0 {
            velocityLoss = (first - last) / first
        }
        return SetSummary(
            repCount: count, meanVelocity: meanVelocity, peakVelocity: peakVelocity,
            meanROM: meanROM, velocityLoss: velocityLoss
        )
    }
}
