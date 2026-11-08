import Foundation

/// 一組（set）的摘要指標（docs/ALGORITHMS.md §6 組別摘要）。
///
/// 全部為 SI 單位。`velocityLoss` 為比例（例如 0.143 代表 14.3%）；只有 1 下時為 nil。
public struct SetSummary: Codable, Sendable, Equatable {
    /// 有效次數。
    public var repCount: Int
    /// 各下向心 MV 的平均（m/s）。
    public var meanVelocity: Double
    /// 各下向心 PV 的最大值（m/s）。
    public var peakVelocity: Double
    /// 各下 ROM 的平均（公尺）。
    public var meanROM: Double
    /// 速度損失 `(MV_first − MV_last) / MV_first`；只有 1 下時為 nil。
    public var velocityLoss: Double?

    public init(
        repCount: Int,
        meanVelocity: Double,
        peakVelocity: Double,
        meanROM: Double,
        velocityLoss: Double?
    ) {
        self.repCount = repCount
        self.meanVelocity = meanVelocity
        self.peakVelocity = peakVelocity
        self.meanROM = meanROM
        self.velocityLoss = velocityLoss
    }
}
