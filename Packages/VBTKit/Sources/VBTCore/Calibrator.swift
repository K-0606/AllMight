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

    /// scaleMismatch 警告預設門檻（ALGORITHMS §1）：Vision 追蹤框寬中位數與使用者圈直徑的相對差超過此比例 → 警告。
    public static let scaleMismatchThreshold = 0.25
    /// 要判斷 scaleMismatch 至少需要的帶框寬樣本數（太少不可靠就不警告）。
    public static let scaleMismatchMinSamples = 10

    /// 比例尺不符警告（ALGORITHMS §1、DECISIONS D-027/D-029）：
    /// 使用者圈同時兼作比例尺（`scale = 槓片公分 / 圈直徑px`），圈沒貼齊槓片會整體高/低估速度與 ROM。
    /// 以 Vision 追蹤框寬（換算像素）的**中位數**與圈直徑（像素）相對比較，差超過 `thresholdFraction` → 回 true（非阻擋性）。
    ///
    /// **只影響是否顯示警告，不影響任何數值**，故調整門檻不觸發 `analysisVersion` 升版。
    /// 帶框寬的樣本不足（含升級前的舊樣本，`boxWidth` 皆為 nil）時回 false（無從判斷、不警告）。
    public static func scaleMismatch(
        samples: [TrackSample],
        selection: PlateSelection,
        geometry: VideoGeometry,
        thresholdFraction: Double = scaleMismatchThreshold,
        minSamples: Int = scaleMismatchMinSamples
    ) -> Bool {
        guard selection.diameterPx > 0, geometry.widthPx > 0 else { return false }
        let widthsPx = samples.compactMap(\.boxWidth)
            .map { $0 * Double(geometry.widthPx) }
            .filter { $0 > 0 }
        guard widthsPx.count >= minSamples else { return false }
        let medianPx = median(widthsPx)
        let relativeDiff = abs(medianPx - selection.diameterPx) / selection.diameterPx
        return relativeDiff > thresholdFraction
    }

    /// 中位數（奇數取中間、偶數取中間兩值平均）。輸入非空。
    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let n = sorted.count
        if n % 2 == 1 { return sorted[n / 2] }
        return (sorted[n / 2 - 1] + sorted[n / 2]) / 2
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
