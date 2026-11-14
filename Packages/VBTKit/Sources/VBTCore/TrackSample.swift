import Foundation

/// 追蹤器對單一影格的輸出（見 docs/ARCHITECTURE.md §2）。
///
/// 座標為 **Vision 正規化座標**：0–1，原點左下，以轉正後影像為準（見 docs/ALGORITHMS.md §0）。
/// `time` 為秒，相對片段起點。
public struct TrackSample: Codable, Sendable, Equatable {
    /// 相對片段起點的時間（秒）。
    public var time: Double
    /// 追蹤中心 x，Vision 正規化（0–1，原點左下）。
    public var x: Double
    /// 追蹤中心 y，Vision 正規化（0–1，原點左下，向上為正）。
    public var y: Double
    /// 追蹤信心（0–1）。
    public var confidence: Float
    /// Vision 追蹤框寬度，Vision 正規化（0–1，相對轉正後影像寬）；僅追蹤到的幀有值，首幀與缺漏為 nil。
    /// 只用來做 scaleMismatch 比例尺警告（§1），**不進任何速度/ROM 計算**（比例尺用使用者圈，D-006）。
    /// optional 以相容升級前存的樣本檔（舊 JSON 無此欄位 → nil，警告略過）。
    public var boxWidth: Double?

    public init(time: Double, x: Double, y: Double, confidence: Float, boxWidth: Double? = nil) {
        self.time = time
        self.x = x
        self.y = y
        self.confidence = confidence
        self.boxWidth = boxWidth
    }
}
