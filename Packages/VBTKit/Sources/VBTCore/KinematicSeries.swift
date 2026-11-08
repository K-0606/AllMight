import Foundation

/// 等間隔的運動學序列（見 docs/ARCHITECTURE.md §2）。給次數切分、指標與圖表使用。
///
/// 全部等長、等間隔 `dt`（秒）。位置與水平位置為公尺（平滑後）；速度 m/s、加速度 m/s²。
/// 垂直向上為正（Vision 原點左下，已轉正）。`scale` 為 m/px（ALGORITHMS §1）。
public struct KinematicSeries: Codable, Sendable, Equatable {
    /// 取樣間隔（秒）。
    public var dt: Double
    /// 等間隔時間（秒）。
    public var time: [Double]
    /// 垂直位置（公尺，平滑後，向上為正）。
    public var position: [Double]
    /// 垂直速度（m/s）。
    public var velocity: [Double]
    /// 垂直加速度（m/s²）。
    public var acceleration: [Double]
    /// 水平位置（公尺，平滑後）；只用來畫軌跡（ALGORITHMS §2）。
    public var horizontalPosition: [Double]
    /// 比例尺（m/px，ALGORITHMS §1）。
    public var scale: Double

    public init(
        dt: Double,
        time: [Double],
        position: [Double],
        velocity: [Double],
        acceleration: [Double],
        horizontalPosition: [Double],
        scale: Double
    ) {
        self.dt = dt
        self.time = time
        self.position = position
        self.velocity = velocity
        self.acceleration = acceleration
        self.horizontalPosition = horizontalPosition
        self.scale = scale
    }
}
