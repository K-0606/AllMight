import Testing
import Foundation
@testable import VBTCore

/// 次數切分驗收（docs/ALGORITHMS.md §5、§8 邊界）。
@Suite("次數切分")
struct RepSegmenterTests {
    let geometry = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
    let selection = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)
    let plateDiameterCm = 45.0

    /// 跑合成訊號 → 完整運動學管線 → 回傳序列（與端對端測試同一條路）。
    func series(_ r: SignalGenerator.Result) throws -> KinematicSeries {
        try Kinematics.computeSeries(
            samples: r.samples, selection: r.selection, geometry: r.geometry,
            plateDiameterCm: r.plateDiameterCm, parameters: .standard
        )
    }

    func threeReps(seed: UInt64 = 20260401, fps: Double = 60) -> SignalGenerator.Result {
        let geo = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: fps)
        return SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: fps, geometry: geo, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: seed
        )
    }

    @Test("3 下半正弦（硬舉順序）切出 3 下，每下都配到離心")
    func threeRepsDeadlift() throws {
        let s = try series(threeReps())
        let reps = RepSegmenter.segment(series: s, exercise: .conventionalDeadlift, parameters: .standard)
        #expect(reps.count == 3)
        #expect(reps.allSatisfy { $0.eccentric != nil })
    }

    @Test("3 下半正弦（蹲舉順序）切出 3 下")
    func threeRepsSquat() throws {
        let s = try series(threeReps())
        let reps = RepSegmenter.segment(series: s, exercise: .backSquat, parameters: .standard)
        #expect(reps.count == 3)
    }

    @Test("只有 1 下也切出 1 下")
    func singleRep() throws {
        let geo = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
        let r = SignalGenerator.generate(
            reps: 1, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.35,
            pauseDuration: 0.4, fps: 60, geometry: geo, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 5
        )
        let s = try series(r)
        let reps = RepSegmenter.segment(series: s, exercise: .backSquat, parameters: .standard)
        #expect(reps.count == 1)
    }

    @Test("完全沒有動作 → 0 下")
    func noMotion() throws {
        let fps = 60.0
        var rng = SplitMix64(seed: 7)
        let noiseNormY = 2.0 / 1920
        let samples = (0..<120).map { i in
            TrackSample(time: Double(i) / fps, x: 0.5, y: 0.3 + rng.nextGaussian() * noiseNormY, confidence: 0.9)
        }
        let s = try Kinematics.computeSeries(
            samples: samples, selection: selection, geometry: geometry,
            plateDiameterCm: plateDiameterCm, parameters: .standard
        )
        let reps = RepSegmenter.segment(series: s, exercise: .backSquat, parameters: .standard)
        #expect(reps.isEmpty)
    }

    @Test("從動作中間開始：不完整的首下（ROM < minROM）被忽略，其餘 2 下保留")
    func startMidMotion() throws {
        let r = threeReps()
        // 時間軸：pause 0.4 + con1 0.5（起點 t=0.4）。切在 con1 中點 t≈0.65（index ≈ 39），
        // 使首下殘餘位移 ≈ 0.064 m < minROM 0.10 → 被忽略。
        let cut = Int(0.65 * 60)
        let trimmed = SignalGenerator.Result(
            samples: Array(r.samples[cut...]), concentrics: r.concentrics,
            selection: r.selection, geometry: r.geometry, plateDiameterCm: r.plateDiameterCm
        )
        let s = try series(trimmed)
        let reps = RepSegmenter.segment(series: s, exercise: .conventionalDeadlift, parameters: .standard)
        #expect(reps.count == 2)
    }

    @Test("30fps 也切出 3 下")
    func threeRepsAt30fps() throws {
        let s = try series(threeReps(seed: 31, fps: 30))
        let reps = RepSegmenter.segment(series: s, exercise: .conventionalDeadlift, parameters: .standard)
        #expect(reps.count == 3)
    }

    @Test("變動影格率（±30% 間隔抖動）仍切出 3 下")
    func threeRepsVariableFrameRate() throws {
        let r = SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: 60, geometry: geometry, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 888,
            timeJitter: 0.3, jitterSeed: 13
        )
        let s = try series(r)
        let reps = RepSegmenter.segment(series: s, exercise: .conventionalDeadlift, parameters: .standard)
        #expect(reps.count == 3)
    }

    @Test("內部缺漏（= maxGapFrames）經內插後仍切出 3 下")
    func threeRepsWithGap() throws {
        // = maxGapFrames + 1 應丟 trackingLost 的情境由 GapFiller/PlateTracker 層測試涵蓋（M3），
        // 這裡只驗 = maxGapFrames 內插後次數仍正確。
        var r = threeReps(seed: 4242)
        for i in 30...35 { r.samples[i].confidence = 0.1 } // 連續 6 幀 = maxGapFrames
        let s = try series(r)
        let reps = RepSegmenter.segment(series: s, exercise: .conventionalDeadlift, parameters: .standard)
        #expect(reps.count == 3)
    }

    @Test("向心中途速度下陷（仍單調上升）不會被切成兩下")
    func stickingPointStaysOneRep() {
        // 向心中段速度短暫掉到 velThreshold 以下但仍為正（位置持續上升，模擬黏滯點）：
        // 偵測成兩個核心，延伸到相同底與頂後去重 → 仍是 1 下。
        let s = makeSeries(segments: [
            (0, 10), (0.30, 15), (0.02, 8), (0.30, 15), (0, 10),
        ])
        let reps = RepSegmenter.segment(series: s, exercise: .conventionalDeadlift, parameters: .standard)
        #expect(reps.count == 1)
    }

    /// 由各段固定速度堆出一條序列（位置為速度的累積積分），零速段當作停頓分隔相位。
    /// 用來精確測「無對應向心的離心不算一下」與配對方向，不經過 SG/雜訊。
    func makeSeries(segments: [(v: Double, frames: Int)], fps: Double = 60) -> KinematicSeries {
        let dt = 1.0 / fps
        var time: [Double] = []
        var position: [Double] = []
        var velocity: [Double] = []
        var tCur = 0.0
        var pCur = 0.0
        for seg in segments {
            for _ in 0..<seg.frames {
                time.append(tCur)
                position.append(pCur)
                velocity.append(seg.v)
                pCur += seg.v * dt
                tCur += dt
            }
        }
        let n = velocity.count
        return KinematicSeries(
            dt: dt, time: time, position: position, velocity: velocity,
            acceleration: Array(repeating: 0, count: n),
            horizontalPosition: Array(repeating: 0, count: n), scale: 0.001
        )
    }

    @Test("最後放下槓鈴（蹲舉）：尾端離心無對應向心，只算 1 下且配到前面的離心")
    func trailingEccentricSquat() {
        // ecc A → pause → con B → pause → ecc C（放下槓鈴）。
        let s = makeSeries(segments: [
            (0, 10), (-0.3, 20), (0, 10), (0.4, 20), (0, 10), (-0.4, 20), (0, 10),
        ])
        let reps = RepSegmenter.segment(series: s, exercise: .backSquat, parameters: .standard)
        #expect(reps.count == 1)
        // 蹲舉配「之前」的離心 A（起點 time 0.167 附近），不是放下槓鈴的 C。
        #expect(reps.first?.eccentric != nil)
        #expect(reps.first?.eccentric?.startIndex == 10)
    }

    @Test("硬舉配「之後」的離心：首段離心無對應向心被忽略")
    func leadingEccentricDeadlift() {
        // ecc A → pause → con B → pause → ecc C。硬舉配之後 → rep = (B, C)，A 被忽略。
        let s = makeSeries(segments: [
            (0, 10), (-0.3, 20), (0, 10), (0.4, 20), (0, 10), (-0.4, 20), (0, 10),
        ])
        let reps = RepSegmenter.segment(series: s, exercise: .conventionalDeadlift, parameters: .standard)
        #expect(reps.count == 1)
        #expect(reps.first?.eccentric?.startIndex == 70)
    }
}
