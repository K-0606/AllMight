import Testing
import Foundation
@testable import VBTCore

/// 指標計算驗收（docs/ALGORITHMS.md §6、§8）。
@Suite("指標計算")
struct MetricsCalculatorTests {
    let geometry = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
    let selection = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)
    let plateDiameterCm = 45.0

    @Test("3 下半正弦：每下向心 MV 誤差 < 0.02 m/s、ROM 誤差 < 1 cm")
    func threeRepsAccuracy() throws {
        let r = SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: 60, geometry: geometry, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 20260402
        )
        let s = try Kinematics.computeSeries(
            samples: r.samples, selection: r.selection, geometry: r.geometry,
            plateDiameterCm: r.plateDiameterCm, parameters: .standard
        )
        let reps = RepSegmenter.segment(series: s, exercise: .conventionalDeadlift, parameters: .standard)
        let (metrics, summary) = MetricsCalculator.metrics(for: reps, series: s)
        #expect(summary.repCount == 3)
        for (m, c) in zip(metrics, r.concentrics) {
            #expect(abs(m.concentric.meanVelocity - c.meanVelocity) < 0.02,
                    "MV \(m.concentric.meanVelocity) vs \(c.meanVelocity)")
            #expect(abs(m.concentric.displacement - c.rom) < 0.01,
                    "ROM \(m.concentric.displacement) vs \(c.rom)")
        }
        // 速度剖面相同的三下 → 速度損失接近 0。
        #expect(abs(summary.velocityLoss ?? 1) < 0.1)
    }

    /// 由各段固定速度堆出序列（位置為速度累積積分，零速段為停頓）。
    func constantSeries(segments: [(v: Double, frames: Int)], fps: Double = 60) -> KinematicSeries {
        let dt = 1.0 / fps
        var time: [Double] = []
        var position: [Double] = []
        var velocity: [Double] = []
        var tCur = 0.0
        var pCur = 0.0
        for seg in segments {
            for _ in 0..<seg.frames {
                time.append(tCur); position.append(pCur); velocity.append(seg.v)
                pCur += seg.v * dt; tCur += dt
            }
        }
        let n = velocity.count
        return KinematicSeries(
            dt: dt, time: time, position: position, velocity: velocity,
            acceleration: Array(repeating: 0, count: n),
            horizontalPosition: Array(repeating: 0, count: n), scale: 0.001
        )
    }

    @Test("速度損失＝(第一下 − 最後一下) / 第一下，摘要統計正確")
    func velocityLossAndSummary() {
        // 三下固定速度 0.30 / 0.27 / 0.24，各 30 幀（ROM 0.15 / 0.135 / 0.12 m）。
        let s = constantSeries(segments: [
            (0, 10), (0.30, 30), (0, 10), (0.27, 30), (0, 10), (0.24, 30), (0, 10),
        ])
        let reps = RepSegmenter.segment(series: s, exercise: .backSquat, parameters: .standard)
        let (metrics, summary) = MetricsCalculator.metrics(for: reps, series: s)
        #expect(summary.repCount == 3)
        #expect(abs(metrics[0].concentric.meanVelocity - 0.30) < 1e-9)
        #expect(abs(metrics[2].concentric.meanVelocity - 0.24) < 1e-9)
        #expect(abs((summary.velocityLoss ?? 0) - (0.30 - 0.24) / 0.30) < 1e-9)
        #expect(abs(summary.meanVelocity - (0.30 + 0.27 + 0.24) / 3) < 1e-9)
        #expect(abs(summary.peakVelocity - 0.30) < 1e-9)
        #expect(abs(summary.meanROM - (0.15 + 0.135 + 0.12) / 3) < 1e-9)
        // 相對第 1 下：第 3 下 (0.24−0.30)/0.30 = −0.20。
        #expect(abs((metrics[2].dropFromFirst ?? 0) + 0.20) < 1e-9)
        #expect(metrics[0].dropFromFirst == nil)
    }

    @Test("只有 1 下時速度損失為 nil")
    func singleRepVelocityLossNil() {
        let s = constantSeries(segments: [(0, 10), (0.30, 30), (0, 10)])
        let reps = RepSegmenter.segment(series: s, exercise: .backSquat, parameters: .standard)
        let (_, summary) = MetricsCalculator.metrics(for: reps, series: s)
        #expect(summary.repCount == 1)
        #expect(summary.velocityLoss == nil)
    }

    @Test("restAfter＝下一下起點 − 這一下終點")
    func restAfter() {
        let s = constantSeries(segments: [
            (0, 10), (0.30, 30), (0, 10), (0.27, 30), (0, 10),
        ])
        let reps = RepSegmenter.segment(series: s, exercise: .backSquat, parameters: .standard)
        let (metrics, _) = MetricsCalculator.metrics(for: reps, series: s)
        // con1 延伸到頂（幀 40，終點 t=40/60），con2 起點幀 50（t=50/60）→ 間隔 10/60。
        #expect(abs((metrics[0].restAfter ?? 0) - 10.0 / 60.0) < 1e-9)
        #expect(metrics[1].restAfter == nil)
    }

    /// 直接給定序列與相位來精確驗 MPV 的推進段界定（不經過切分與 SG）。
    func seriesFrom(velocity: [Double], acceleration: [Double], dt: Double = 0.01) -> KinematicSeries {
        var time: [Double] = []
        var position: [Double] = []
        var p = 0.0
        for (i, v) in velocity.enumerated() {
            time.append(Double(i) * dt)
            position.append(p)
            p += v * dt
            _ = i
        }
        return KinematicSeries(
            dt: dt, time: time, position: position, velocity: velocity,
            acceleration: acceleration,
            horizontalPosition: Array(repeating: 0, count: velocity.count), scale: 0.001
        )
    }

    @Test("MPV：推進段止於 PV 後第一個 a < −9.81 的前一點")
    func mpvBrakingPoint() {
        // PV 在 index 4；a[5] = −20（第一個煞車點）→ k = 4。MPV = p[4]/t[4]。
        let v = [0.1, 0.2, 0.3, 0.4, 0.5, 0.4, 0.3, 0.2, 0.1]
        var a = Array(repeating: 0.0, count: v.count)
        a[5] = -20
        let s = seriesFrom(velocity: v, acceleration: a)
        let rep = SegmentedRep(
            concentric: Phase(kind: .concentric, startIndex: 0, endIndex: v.count - 1,
                              startTime: s.time[0], endTime: s.time[v.count - 1]),
            eccentric: nil
        )
        let (metrics, _) = MetricsCalculator.metrics(for: [rep], series: s)
        let expectedMPV = s.position[4] / s.time[4]
        #expect(abs(metrics[0].mpv - expectedMPV) < 1e-9)
    }

    @Test("MPV：沒有煞車點時退回整段向心平均速度")
    func mpvNoBraking() {
        let v = [0.1, 0.2, 0.3, 0.4, 0.5, 0.4, 0.3, 0.2, 0.1]
        let a = Array(repeating: 0.0, count: v.count) // 無 a < −9.81
        let s = seriesFrom(velocity: v, acceleration: a)
        let e = v.count - 1
        let rep = SegmentedRep(
            concentric: Phase(kind: .concentric, startIndex: 0, endIndex: e,
                              startTime: s.time[0], endTime: s.time[e]),
            eccentric: nil
        )
        let (metrics, _) = MetricsCalculator.metrics(for: [rep], series: s)
        let fullMV = (s.position[e] - s.position[0]) / (s.time[e] - s.time[0])
        #expect(abs(metrics[0].mpv - fullMV) < 1e-9)
    }
}
