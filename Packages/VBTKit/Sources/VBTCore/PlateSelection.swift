import Foundation

/// 使用者在起點幀對齊的槓片圓圈（見 docs/ARCHITECTURE.md §2、DECISIONS D-006）。
///
/// 圓心以 **Vision 正規化座標**表示（0–1，原點左下，轉正後影像）；
/// 直徑以轉正後影像的像素表示，作為比例尺來源（見 docs/ALGORITHMS.md §1）。
/// 比例尺只用此圓圈，不用追蹤框大小（追蹤框只做 25% 差異警告）。
public struct PlateSelection: Codable, Sendable, Equatable {
    /// 圓心 x，Vision 正規化（0–1，原點左下）。
    public var centerX: Double
    /// 圓心 y，Vision 正規化（0–1，原點左下）。
    public var centerY: Double
    /// 圓圈直徑，轉正後影像的像素。
    public var diameterPx: Double

    public init(centerX: Double, centerY: Double, diameterPx: Double) {
        self.centerX = centerX
        self.centerY = centerY
        self.diameterPx = diameterPx
    }
}
