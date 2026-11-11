import Testing
import Foundation
@testable import VBTCore

/// `SetAnalyzer.analyze`（從原始樣本重算完整分析的純函式）：驗證它與直接串
/// Kinematics→RepSegmenter→MetricsCalculator 等價，並處理沒有次數的情況。
/// 這是 `analysisVersion` 升級時「用存好的樣本重算、不重新追蹤」所走的同一段程式（DECISIONS D-030）。
@Suite("SetAnalyzer")
struct SetAnalyzerTests {
    let geometry = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
    let selection = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)
    let plateDiameterCm = 45.0 // 比例尺 0.001 m/px

    @Test("3 下合成訊號：次數=3、摘要合理、analysisVersion 為目前版本")
    func threeReps() throws {
        let r = SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: 60, geometry: geometry, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 20260308
        )
        let analysis = try SetAnalyzer.analyze(
            samples: r.samples, selection: r.selection, geometry: r.geometry,
            plateDiameterCm: r.plateDiameterCm, exercise: .conventionalDeadlift
        )
        #expect(analysis.reps.count == 3)
        #expect(analysis.summary.repCount == 3)
        #expect(analysis.analysisVersion == VBTCore.analysisVersion)
        // 半正弦 Vc=0.4 → 每下向心 MV = 2·Vc/π ≈ 0.2546 m/s（§8 容差 0.02）。
        #expect(abs(analysis.summary.meanVelocity - 2 * 0.4 / .pi) < 0.02)
        #expect(analysis.summary.meanROM > 0.10)
    }

    @Test("等價：analyze 的序列與直接呼叫 Kinematics.computeSeries 相同")
    func equivalentToDirectChain() throws {
        let r = SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: 60, geometry: geometry, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 321
        )
        let direct = try Kinematics.computeSeries(
            samples: r.samples, selection: r.selection, geometry: r.geometry,
            plateDiameterCm: r.plateDiameterCm, parameters: .standard
        )
        let analysis = try SetAnalyzer.analyze(
            samples: r.samples, selection: r.selection, geometry: r.geometry,
            plateDiameterCm: r.plateDiameterCm, exercise: .conventionalDeadlift
        )
        // 整條鏈等價：序列、切分、指標都與直接呼叫相同（RepMetrics/SetSummary 為 Equatable）。
        let reps = RepSegmenter.segment(series: direct, exercise: .conventionalDeadlift, parameters: .standard)
        let (expectedReps, expectedSummary) = MetricsCalculator.metrics(for: reps, series: direct)
        #expect(analysis.series == direct)
        #expect(analysis.reps == expectedReps)
        #expect(analysis.summary == expectedSummary)
    }

    @Test("samples 含過大缺漏時丟 trackingLost")
    func trackingLostThrows() {
        var r = SignalGenerator.generate(
            reps: 3, concentricDuration: 0.5, eccentricDuration: 0.6, peakVelocity: 0.4,
            pauseDuration: 0.4, fps: 60, geometry: geometry, selection: selection,
            plateDiameterCm: plateDiameterCm, noiseSigmaPx: 2, seed: 42
        )
        // 連續缺漏超過 maxGapFrames（無法內插）→ Kinematics 丟 trackingLost，由 analyze 傳出。
        let maxGap = AnalysisParameters.standard.maxGapFrames
        for i in 30...(30 + maxGap + 2) { r.samples[i].confidence = 0.1 }
        #expect(throws: AnalysisError.self) {
            try SetAnalyzer.analyze(
                samples: r.samples, selection: r.selection, geometry: r.geometry,
                plateDiameterCm: r.plateDiameterCm, exercise: .conventionalDeadlift
            )
        }
    }

    @Test("沒有動作時丟 noRepsDetected")
    func noMotionThrows() {
        let fps = 60.0
        var rng = SplitMix64(seed: 7)
        let noiseNormY = 2.0 / 1920
        let samples = (0..<120).map { i in
            TrackSample(time: Double(i) / fps, x: 0.5, y: 0.3 + rng.nextGaussian() * noiseNormY, confidence: 0.9)
        }
        #expect(throws: AnalysisError.noRepsDetected) {
            try SetAnalyzer.analyze(
                samples: samples, selection: selection, geometry: geometry,
                plateDiameterCm: plateDiameterCm, exercise: .backSquat
            )
        }
    }
}
