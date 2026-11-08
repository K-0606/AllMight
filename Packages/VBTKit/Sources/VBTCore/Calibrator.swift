import Foundation

/// 校正後的樣本：時間（秒）、公尺位置（以第一個樣本為原點）、保留信心供缺漏判斷。
///
/// `y` 向上為正（Vision 原點左下，已轉正）；`x` 只用來畫軌跡（ALGORITHMS §2）。
public struct CalibratedSample: Sendable, Equatable {
    /// 相對片段起點的時間（秒）。
    public var time: Double
    /// 水平位移（公尺，相對第一個樣本）；只用來畫軌跡。
    public var x: Double
    /// 垂直位移（公尺，相對第一個樣本，向上為正）。
    public var y: Double
    /// 追蹤信心（0–1），缺漏判斷用。
    public var confidence: Float

    public init(time: Double, x: Double, y: Double, confidence: Float) {
        self.time = time
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

/// 比例尺與位置換算（docs/ALGORITHMS.md §1–2）。純函式。
///
/// 比例尺只用使用者對齊的圓圈直徑（DECISIONS D-006），不用追蹤框大小。
/// 座標為 Vision 正規化（0–1，原點左下，已轉正）；內部單位一律公尺。
public enum Calibrator {
    /// 比例尺 m/px（ALGORITHMS §1）：`plateDiameterCm / 100 / diameterPx`。
    public static func scale(plateDiameterCm: Double, selection: PlateSelection) -> Double {
        guard selection.diameterPx > 0 else { return 0 }
        return plateDiameterCm / 100 / selection.diameterPx
    }

    /// 把追蹤樣本換算成公尺位置（ALGORITHMS §2），以第一個樣本為原點。
    ///
    /// `y_m[i] = (y[i] − y[0]) × heightPx × scale`、`x_m[i] = (x[i] − x[0]) × widthPx × scale`。
    /// 原點為常數位移，不影響速度與位移幅度（ROM），僅平移絕對位置。
    public static func calibrate(
        samples: [TrackSample],
        selection: PlateSelection,
        geometry: VideoGeometry,
        plateDiameterCm: Double
    ) -> [CalibratedSample] {
        guard let first = samples.first else { return [] }
        let s = scale(plateDiameterCm: plateDiameterCm, selection: selection)
        let w = Double(geometry.widthPx)
        let h = Double(geometry.heightPx)
        return samples.map { sample in
            CalibratedSample(
                time: sample.time,
                x: (sample.x - first.x) * w * s,
                y: (sample.y - first.y) * h * s,
                confidence: sample.confidence
            )
        }
    }
}
