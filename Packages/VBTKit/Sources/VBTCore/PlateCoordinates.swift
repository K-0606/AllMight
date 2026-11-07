import Foundation

/// 點數／像素座標矩形（原點左上），用純 `Double` 表示。
///
/// VBTCore 不得使用 CoreGraphics，因此座標轉換自備此型別，
/// 讓轉換函式保持純粹、可在 macOS 上 `swift test`（見 .claude/rules/vbtkit.md）。
public struct LayoutRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// 點選畫面與 Vision 正規化座標之間的純函式轉換（見 docs/ALGORITHMS.md §0、skill plate-tracking §1）。
///
/// 全部以「轉正後影像」為基準：view 以 aspect-fit 置中顯示影像，座標先扣掉 letterbox，
/// 再換算成 Vision 正規化（0–1，原點左下）。所有輸入／輸出單位都在名稱或註解標明。
public enum PlateCoordinates {
    /// 影像以 aspect-fit 置中顯示在容器內時，影像實際占據的區域（扣掉 letterbox）。
    ///
    /// 容器與影像都以點數、原點左上；回傳的 `LayoutRect` 也是點數、原點左上。
    public static func aspectFitRect(
        containerWidth: Double,
        containerHeight: Double,
        imageWidth: Double,
        imageHeight: Double
    ) -> LayoutRect {
        guard containerWidth > 0, containerHeight > 0, imageWidth > 0, imageHeight > 0 else {
            return LayoutRect(x: 0, y: 0, width: 0, height: 0)
        }
        let scale = min(containerWidth / imageWidth, containerHeight / imageHeight)
        let displayWidth = imageWidth * scale
        let displayHeight = imageHeight * scale
        return LayoutRect(
            x: (containerWidth - displayWidth) / 2,
            y: (containerHeight - displayHeight) / 2,
            width: displayWidth,
            height: displayHeight
        )
    }

    /// SwiftUI 點擊（原點左上，相對容器）→ Vision 正規化座標（0–1，原點左下，相對影像）。
    ///
    /// `imageRect` 是影像在容器中的顯示區域（`aspectFitRect` 的輸出）。
    /// 回傳值夾在 0–1；落在 letterbox 區域的點會被夾到邊界。
    /// ALGORITHMS §0：`xN = (x − minX) / width`、`yN = 1 − (y − minY) / height`。
    public static func visionNormalizedPoint(
        viewX: Double,
        viewY: Double,
        in imageRect: LayoutRect
    ) -> (x: Double, y: Double) {
        guard imageRect.width > 0, imageRect.height > 0 else { return (0, 0) }
        let xN = (viewX - imageRect.x) / imageRect.width
        let yN = 1 - (viewY - imageRect.y) / imageRect.height
        return (clamp01(xN), clamp01(yN))
    }

    /// 圓圈直徑（點數，view 空間）→ 轉正後影像的像素。
    ///
    /// plate-tracking §1：`diameterPx = diameterPt / imageRect.width × orientedWidthPx`。
    public static func diameterPixels(
        diameterPoints: Double,
        imageRectWidth: Double,
        orientedWidthPx: Int
    ) -> Double {
        guard imageRectWidth > 0 else { return 0 }
        return diameterPoints / imageRectWidth * Double(orientedWidthPx)
    }

    /// 由 view 空間的圓心與直徑，直接建出 `PlateSelection`（Vision 正規化圓心 + 像素直徑）。
    ///
    /// `circleCenterView` 與 `diameterPoints` 以點數、原點左上；`imageRect` 為影像顯示區域。
    public static func selection(
        circleCenterViewX: Double,
        circleCenterViewY: Double,
        diameterPoints: Double,
        imageRect: LayoutRect,
        orientedWidthPx: Int
    ) -> PlateSelection {
        let center = visionNormalizedPoint(viewX: circleCenterViewX, viewY: circleCenterViewY, in: imageRect)
        let diameterPx = diameterPixels(
            diameterPoints: diameterPoints,
            imageRectWidth: imageRect.width,
            orientedWidthPx: orientedWidthPx
        )
        return PlateSelection(centerX: center.x, centerY: center.y, diameterPx: diameterPx)
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
