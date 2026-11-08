import Foundation

/// 次數切分狀態機的相位種類（docs/ALGORITHMS.md §5）。
///
/// `concentric` 向心（上推/上拉）、`eccentric` 離心（下放）、`pause` 停頓/靜止。
public enum PhaseKind: String, Codable, Sendable {
    case concentric
    case eccentric
    case pause
}

/// 一個運動相位在等間隔運動學序列上的區間（docs/ARCHITECTURE.md §2、ALGORITHMS §5）。
///
/// 索引對應 `KinematicSeries` 的等間隔網格；`[startIndex, endIndex]` 為閉區間。
/// 時間單位為秒，相對片段起點。相位起點已回推到速度跨過 0 的那一點（ALGORITHMS §5）。
public struct Phase: Codable, Sendable, Equatable {
    /// 相位種類。
    public var kind: PhaseKind
    /// 起點索引（含）。
    public var startIndex: Int
    /// 終點索引（含）。
    public var endIndex: Int
    /// 起點時間（秒）。
    public var startTime: Double
    /// 終點時間（秒）。
    public var endTime: Double

    public init(
        kind: PhaseKind,
        startIndex: Int,
        endIndex: Int,
        startTime: Double,
        endTime: Double
    ) {
        self.kind = kind
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.startTime = startTime
        self.endTime = endTime
    }
}
