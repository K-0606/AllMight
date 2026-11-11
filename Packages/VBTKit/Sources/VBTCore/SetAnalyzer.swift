import Foundation

/// 從原始追蹤樣本算出完整分析結果的純函式（VBTCore，無 I/O、無時間依賴）。
///
/// 串起 §1–§6 的 VBTCore 計算鏈：`Kinematics.computeSeries`（運動學）→ `RepSegmenter.segment`
/// （次數切分）→ `MetricsCalculator.metrics`（指標）→ `SetAnalysis`。
/// 這是 `AnalysisPipeline`（VBTVision）追蹤完成後所走的同一段計算，獨立成純函式供：
/// (a) 即時分析與 (b) `analysisVersion` 升級時「用存好的樣本重算、不重新追蹤」共用（見 DECISIONS D-007、D-030）。
public enum SetAnalyzer {
    /// 用追蹤樣本重算一次完整分析。
    ///
    /// - Parameters:
    ///   - samples: 追蹤輸出，Vision 正規化座標（0–1，原點左下，已轉正；見 ALGORITHMS §0）。
    ///   - selection: 使用者圈選的槓片（比例尺來源，§1）。
    ///   - geometry: 轉正後影片幾何（像素尺寸與 fps）。
    ///   - plateDiameterCm: 槓片實際直徑（公分），換算比例尺用。
    ///   - exercise: 動作（決定次數切分的相位順序，§5）。
    ///   - parameters: 演算法參數（§7），預設 `.standard`。
    /// - Returns: `SetAnalysis`，`analysisVersion` 標記為目前版本。
    /// - Throws: `AnalysisError.trackingLost`（缺漏過大無法內插）、`AnalysisError.noRepsDetected`（切不出有效次數）。
    public static func analyze(
        samples: [TrackSample],
        selection: PlateSelection,
        geometry: VideoGeometry,
        plateDiameterCm: Double,
        exercise: Exercise,
        parameters: AnalysisParameters = .standard
    ) throws -> SetAnalysis {
        let series = try Kinematics.computeSeries(
            samples: samples,
            selection: selection,
            geometry: geometry,
            plateDiameterCm: plateDiameterCm,
            parameters: parameters
        )
        let reps = RepSegmenter.segment(series: series, exercise: exercise, parameters: parameters)
        guard !reps.isEmpty else { throw AnalysisError.noRepsDetected }
        let (repMetrics, summary) = MetricsCalculator.metrics(for: reps, series: series)

        return SetAnalysis(
            analysisVersion: VBTCore.analysisVersion,
            parameters: parameters,
            reps: repMetrics,
            summary: summary,
            series: series
        )
    }
}
