import Foundation

/// 影片轉正（套用 preferredTransform）後的幾何資訊。
///
/// 尺寸為轉正後的像素；`nominalFPS` 是影片軌道標稱影格率（track.nominalFrameRate）。
/// 座標相關計算一律以「轉正後影像」為基準（見 .claude/rules/vbtkit.md）。
public struct VideoGeometry: Codable, Sendable, Equatable {
    /// 轉正後寬度（像素）。
    public var widthPx: Int
    /// 轉正後高度（像素）。
    public var heightPx: Int
    /// 標稱影格率（fps）。
    public var nominalFPS: Double

    public init(widthPx: Int, heightPx: Int, nominalFPS: Double) {
        self.widthPx = widthPx
        self.heightPx = heightPx
        self.nominalFPS = nominalFPS
    }
}
