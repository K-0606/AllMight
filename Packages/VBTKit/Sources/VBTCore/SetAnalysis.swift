import Foundation

/// 一次完整分析的結果（docs/ARCHITECTURE.md §2）。
///
/// 由 `AnalysisPipeline`（VBTVision）串起追蹤與 VBTCore 計算後產生，存進 `WorkoutSet.analysisData`。
/// `series` 一併保存等間隔運動學序列供圖表與重算使用（見 DECISIONS D-026）。
public struct SetAnalysis: Codable, Sendable, Equatable {
    /// 演算法版本；讀到比目前舊的資料時用樣本重算（見 ARCHITECTURE §4.2）。
    public var analysisVersion: Int
    /// 計算所用的參數。
    public var parameters: AnalysisParameters
    /// 每一下的指標，依時間順序。
    public var reps: [RepMetrics]
    /// 組別摘要。
    public var summary: SetSummary
    /// 等間隔運動學序列（時間、位置、速度、加速度、水平位置、scale）。
    public var series: KinematicSeries

    public init(
        analysisVersion: Int,
        parameters: AnalysisParameters,
        reps: [RepMetrics],
        summary: SetSummary,
        series: KinematicSeries
    ) {
        self.analysisVersion = analysisVersion
        self.parameters = parameters
        self.reps = reps
        self.summary = summary
        self.series = series
    }
}
