import Foundation

/// 分析管線的可調整參數（公式與預設值的唯一來源為 docs/ALGORITHMS.md §7）。
///
/// 所有可調整數值集中於此，不寫死在各型別裡（見 .claude/rules/vbtkit.md）。
/// 追蹤相關門檻（§7 追蹤列、skill plate-tracking §3）影響的是「追蹤」階段，在原始
/// `TrackSample` 產生之前；改這些值需重新追蹤，與 `analysisVersion`（從既有樣本重算）無關。
public struct AnalysisParameters: Codable, Sendable, Equatable {
    /// 追蹤信心下限；低於此的樣本視為缺漏。
    public var minConfidence: Double
    /// 可線性內插的最大連續缺漏影格數；超過即 `trackingLost`。
    public var maxGapFrames: Int
    /// Savitzky-Golay 視窗長度（秒）。
    public var sgWindowSeconds: Double
    /// Savitzky-Golay 多項式階數。
    public var sgOrder: Int
    /// 階段判斷速度門檻（m/s）。
    public var velThreshold: Double
    /// 階段最短持續時間（秒）。
    public var minPhaseSeconds: Double
    /// 有效向心最小位移（公尺）。
    public var minROM: Double
    /// 單幀中心跳動上限，以槓片直徑的倍數表示；超過視為缺漏（不合物理的瞬移）。
    public var maxCenterJumpFactor: Double
    /// 追蹤框面積相對初始框的成長上限倍數；超過視為缺漏。
    public var maxAreaGrowthFactor: Double
    /// 追蹤框面積相對初始框的縮小下限倍數；低於視為缺漏。
    public var minAreaShrinkFactor: Double

    public init(
        minConfidence: Double,
        maxGapFrames: Int,
        sgWindowSeconds: Double,
        sgOrder: Int,
        velThreshold: Double,
        minPhaseSeconds: Double,
        minROM: Double,
        maxCenterJumpFactor: Double,
        maxAreaGrowthFactor: Double,
        minAreaShrinkFactor: Double
    ) {
        self.minConfidence = minConfidence
        self.maxGapFrames = maxGapFrames
        self.sgWindowSeconds = sgWindowSeconds
        self.sgOrder = sgOrder
        self.velThreshold = velThreshold
        self.minPhaseSeconds = minPhaseSeconds
        self.minROM = minROM
        self.maxCenterJumpFactor = maxCenterJumpFactor
        self.maxAreaGrowthFactor = maxAreaGrowthFactor
        self.minAreaShrinkFactor = minAreaShrinkFactor
    }

    /// docs/ALGORITHMS.md §7 的預設值。
    public static let standard = AnalysisParameters(
        minConfidence: 0.30,
        maxGapFrames: 6,
        sgWindowSeconds: 0.15,
        sgOrder: 3,
        velThreshold: 0.05,
        minPhaseSeconds: 0.10,
        minROM: 0.10,
        maxCenterJumpFactor: 0.5,
        maxAreaGrowthFactor: 2.0,
        minAreaShrinkFactor: 0.5
    )
}
