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

    public init(time: Double, x: Double, y: Double, confidence: Float) {
        self.time = time
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}
