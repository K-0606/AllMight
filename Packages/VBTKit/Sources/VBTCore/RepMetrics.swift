import Foundation

/// 單一相位（向心或離心）的指標（docs/ALGORITHMS.md §6）。
///
/// 全部為 SI 單位且為非負量值：位移與平均/峰值速度皆取量級（離心亦取絕對值，見 §6）。
public struct PhaseMetrics: Codable, Sendable, Equatable {
    /// 相位時間長度（秒）。
    public var duration: Double
    /// 平均速度（m/s，離心取絕對值）。
    public var meanVelocity: Double
    /// 峰值速度（m/s，離心取 `max(|v|)`）。
    public var peakVelocity: Double
    /// 位移量級（公尺）；顯示為 cm 時由 App 層換算。
    public var displacement: Double
    /// 相位起點時間（秒，相對片段起點；對應 `Phase.startTime`）。
    /// 供結果頁速度曲線標示每一下的範圍（R1、R2…）。舊紀錄（升級前）為 nil，顯示層略過範圍標示。
    public var startTime: Double?
    /// 相位終點時間（秒，相對片段起點；對應 `Phase.endTime`）。新資料滿足 `duration == endTime − startTime`。
    public var endTime: Double?

    public init(
        duration: Double,
        meanVelocity: Double,
        peakVelocity: Double,
        displacement: Double,
        startTime: Double? = nil,
        endTime: Double? = nil
    ) {
        self.duration = duration
        self.meanVelocity = meanVelocity
        self.peakVelocity = peakVelocity
        self.displacement = displacement
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// 一下（rep）的完整指標（docs/ALGORITHMS.md §6）。
///
/// `concentric.displacement` 即該下的動作幅度 ROM。`mpv` 為推進段平均速度。
/// `restAfter` 與 `dropFromFirst` 為跨下關係，單下時可能為 nil。
/// 離心/向心比（ALGORITHMS §6）為衍生值，不落值；顯示層以
/// `eccentric.meanVelocity / concentric.meanVelocity` 計算。
public struct RepMetrics: Codable, Sendable, Equatable {
    /// 第幾下（從 1 起算）。
    public var index: Int
    /// 向心段指標（每一下必有）。
    public var concentric: PhaseMetrics
    /// 離心段指標（若該下有配對到離心）。
    public var eccentric: PhaseMetrics?
    /// 平均推進速度 MPV（m/s，ALGORITHMS §6）。
    public var mpv: Double
    /// 與下一下第一個相位起點的間隔（秒）；最後一下為 nil。
    public var restAfter: Double?
    /// 相對第 1 下向心 MV 的變化比例（負值為下降）；第 1 下為 nil。
    public var dropFromFirst: Double?

    public init(
        index: Int,
        concentric: PhaseMetrics,
        eccentric: PhaseMetrics?,
        mpv: Double,
        restAfter: Double?,
        dropFromFirst: Double?
    ) {
        self.index = index
        self.concentric = concentric
        self.eccentric = eccentric
        self.mpv = mpv
        self.restAfter = restAfter
        self.dropFromFirst = dropFromFirst
    }
}
