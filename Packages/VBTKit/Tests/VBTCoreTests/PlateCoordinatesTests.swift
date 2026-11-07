import Testing
import Foundation
@testable import VBTCore

/// 座標轉換（docs/ALGORITHMS.md §0、skill plate-tracking §1）的純函式測試。
/// 容差見 docs/ALGORITHMS.md §8：座標相關用 1e-9。
@Suite("座標轉換")
struct PlateCoordinatesTests {
    let tol = 1e-9

    @Test("橫式影像填滿等比例容器時無 letterbox")
    func aspectFitNoLetterbox() {
        let rect = PlateCoordinates.aspectFitRect(
            containerWidth: 1920, containerHeight: 1080,
            imageWidth: 1920, imageHeight: 1080
        )
        #expect(abs(rect.x - 0) < tol)
        #expect(abs(rect.y - 0) < tol)
        #expect(abs(rect.width - 1920) < tol)
        #expect(abs(rect.height - 1080) < tol)
    }

    @Test("直式影像置中在較寬容器時左右留 letterbox")
    func aspectFitPillarbox() {
        // 容器 400×400，影像 9:16（1080×1920）→ 以高度為準，寬 = 400 × 9/16 = 225，左右各留 87.5
        let rect = PlateCoordinates.aspectFitRect(
            containerWidth: 400, containerHeight: 400,
            imageWidth: 1080, imageHeight: 1920
        )
        #expect(abs(rect.height - 400) < tol)
        #expect(abs(rect.width - 225) < tol)
        #expect(abs(rect.x - 87.5) < tol)
        #expect(abs(rect.y - 0) < tol)
    }

    @Test("點擊中心轉為 Vision 正規化 (0.5, 0.5)")
    func tapCenter() {
        let rect = LayoutRect(x: 0, y: 0, width: 200, height: 400)
        let p = PlateCoordinates.visionNormalizedPoint(viewX: 100, viewY: 200, in: rect)
        #expect(abs(p.x - 0.5) < tol)
        #expect(abs(p.y - 0.5) < tol)
    }

    @Test("畫面頂端點擊對應 Vision y 接近 1（原點左下，y 向上翻轉）")
    func tapTopMapsToHighY() {
        let rect = LayoutRect(x: 0, y: 0, width: 200, height: 400)
        let top = PlateCoordinates.visionNormalizedPoint(viewX: 100, viewY: 0, in: rect)
        let bottom = PlateCoordinates.visionNormalizedPoint(viewX: 100, viewY: 400, in: rect)
        #expect(abs(top.y - 1) < tol)
        #expect(abs(bottom.y - 0) < tol)
    }

    @Test("有 letterbox 時點擊換算扣掉偏移")
    func tapWithLetterbox() {
        // 影像顯示在 x=87.5、寬 225、高 400 的區域
        let rect = LayoutRect(x: 87.5, y: 0, width: 225, height: 400)
        // 點在影像水平中點：viewX = 87.5 + 112.5 = 200
        let p = PlateCoordinates.visionNormalizedPoint(viewX: 200, viewY: 200, in: rect)
        #expect(abs(p.x - 0.5) < tol)
        #expect(abs(p.y - 0.5) < tol)
    }

    @Test("落在 letterbox 外的點被夾在 0–1")
    func tapOutsideClamped() {
        let rect = LayoutRect(x: 87.5, y: 0, width: 225, height: 400)
        let left = PlateCoordinates.visionNormalizedPoint(viewX: 0, viewY: 200, in: rect)
        let right = PlateCoordinates.visionNormalizedPoint(viewX: 400, viewY: 200, in: rect)
        #expect(left.x == 0)
        #expect(right.x == 1)
    }

    @Test("直徑由點數換算成轉正後像素")
    func diameterPointsToPixels() {
        // 影像顯示寬 225 pt 對應 1080 px；圓圈 50 pt → 50/225×1080 = 240 px
        let px = PlateCoordinates.diameterPixels(
            diameterPoints: 50, imageRectWidth: 225, orientedWidthPx: 1080
        )
        #expect(abs(px - 240) < 1e-6)
    }

    @Test("直式與橫式容器下同一影像像素位置轉出一致的正規化座標")
    func portraitLandscapeConsistency() {
        // 影像 1080×1920（直式）。影像中心在兩種容器裡都應轉成 (0.5, 0.5)。
        let portrait = PlateCoordinates.aspectFitRect(
            containerWidth: 300, containerHeight: 600, imageWidth: 1080, imageHeight: 1920
        )
        let wide = PlateCoordinates.aspectFitRect(
            containerWidth: 600, containerHeight: 600, imageWidth: 1080, imageHeight: 1920
        )
        let pPortrait = PlateCoordinates.visionNormalizedPoint(
            viewX: portrait.x + portrait.width / 2, viewY: portrait.y + portrait.height / 2, in: portrait
        )
        let pWide = PlateCoordinates.visionNormalizedPoint(
            viewX: wide.x + wide.width / 2, viewY: wide.y + wide.height / 2, in: wide
        )
        #expect(abs(pPortrait.x - 0.5) < tol)
        #expect(abs(pPortrait.y - 0.5) < tol)
        #expect(abs(pWide.x - pPortrait.x) < tol)
        #expect(abs(pWide.y - pPortrait.y) < tol)
    }

    @Test("selection 綜合換算出 Vision 圓心與像素直徑")
    func selectionFactory() {
        let rect = LayoutRect(x: 87.5, y: 0, width: 225, height: 400)
        let sel = PlateCoordinates.selection(
            circleCenterViewX: 200, circleCenterViewY: 200,
            diameterPoints: 50, imageRect: rect, orientedWidthPx: 1080
        )
        #expect(abs(sel.centerX - 0.5) < tol)
        #expect(abs(sel.centerY - 0.5) < tol)
        #expect(abs(sel.diameterPx - 240) < 1e-6)
    }
}
