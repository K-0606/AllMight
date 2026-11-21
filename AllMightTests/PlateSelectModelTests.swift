import Foundation
import Testing
import CoreGraphics
import VBTCore
@testable import AllMight

/// PlateSelectModel 的座標換算測試：圓圈（view 點數）→ PlateSelection（Vision 正規化 + 像素直徑）。
/// 座標數學本身在 VBTCore 測試，這裡驗證 App 層的點擊放置、預設直徑與換算接線正確（PRD §3.5）。
@MainActor
struct PlateSelectModelTests {
    private func makeModel(width: Int, height: Int) -> PlateSelectModel {
        PlateSelectModel(
            videoURL: URL(fileURLWithPath: "/dev/null"),
            geometry: VideoGeometry(widthPx: width, heightPx: height, nominalFPS: 60),
            trimStartSeconds: 0,
            trimEndSeconds: 5
        )
    }

    @Test("一開始沒有圓圈，點擊後才放置")
    func circleAppearsOnlyAfterTap() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 100, height: 200))
        #expect(model.isCirclePlaced == false)
        model.placeCircle(at: CGPoint(x: 50, y: 100))
        #expect(model.isCirclePlaced == true)
    }

    @Test("點擊中央放置：換算成 (0.5, 0.5)、預設直徑為影像寬的 18%")
    func placeAtCenter() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 100, height: 200))
        model.placeCircle(at: CGPoint(x: 50, y: 100))
        let selection = model.currentSelection()
        #expect(abs(selection.centerX - 0.5) < 1e-9)
        #expect(abs(selection.centerY - 0.5) < 1e-9)
        // 直徑 = 影像顯示寬 100 × 0.18 = 18 pt；18/100 × 1000 = 180 px。
        #expect(abs(selection.diameterPx - 180) < 1e-6)
    }

    @Test("有 letterbox 的容器：點擊換算扣掉置中偏移，直徑以影像顯示寬為基準")
    func letterboxConversion() {
        let model = makeModel(width: 1000, height: 2000)
        // 容器 200×200，直式影像 → 影像顯示寬 100、置中於 x=50。
        model.updateContainer(size: CGSize(width: 200, height: 200))
        model.placeCircle(at: CGPoint(x: 100, y: 100)) // 影像中央
        let selection = model.currentSelection()
        #expect(abs(selection.centerX - 0.5) < 1e-9)
        #expect(abs(selection.centerY - 0.5) < 1e-9)
        #expect(abs(selection.diameterPx - 180) < 1e-6) // 100 × 0.18 / 100 × 1000
    }

    @Test("放置後移動圓心換算出對應的 Vision 正規化座標（y 向上翻轉）")
    func moveCircleMapsCoordinates() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 100, height: 200))
        model.placeCircle(at: CGPoint(x: 50, y: 100))
        model.moveCircle(to: CGPoint(x: 25, y: 50))
        let selection = model.currentSelection()
        #expect(abs(selection.centerX - 0.25) < 1e-9)
        #expect(abs(selection.centerY - 0.75) < 1e-9) // 1 − 50/200
    }

    @Test("移動圓心超出影像範圍時被夾回影像內")
    func moveCircleClamped() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 200, height: 200))
        model.placeCircle(at: CGPoint(x: 100, y: 100))
        model.moveCircle(to: CGPoint(x: 0, y: 100)) // x=0 在左側 letterbox 外
        #expect(model.circleCenter.x >= 50 - 1e-9) // 影像左緣在 x=50
    }

    @Test("縮放圓圈後直徑夾在影像較短邊的比例範圍內")
    func scaleCircleClamped() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 100, height: 200))
        model.placeCircle(at: CGPoint(x: 50, y: 100))
        model.scaleCircle(by: 100) // 嘗試放超大
        #expect(model.circleDiameter <= 100 + 1e-9) // 不超過較短邊 100
        model.scaleCircle(by: 0.0001) // 嘗試縮超小
        #expect(model.circleDiameter >= 100 * 0.05 - 1e-9) // 不小於較短邊 5%
    }

    @Test("偵測框換算成 view 矩形：中心/大小正確、y 向上翻轉")
    func boxRectMapsDetection() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 100, height: 200)) // 影像填滿，rect=(0,0,100,200)
        let plate = DetectedPlate(centerX: 0.5, centerY: 0.6, width: 0.2, height: 0.15, confidence: 0.8)
        let r = model.boxRect(for: plate)
        #expect(abs(r.midX - 50) < 1e-9)
        #expect(abs(r.midY - 80) < 1e-9) // (1 − 0.6) × 200 = 80（原點左下→左上翻轉）
        #expect(abs(r.width - 20) < 1e-9)  // 0.2 × 100
        #expect(abs(r.height - 30) < 1e-9) // 0.15 × 200
    }

    // MARK: - Stage 2：點選偵測框（見 DECISIONS D-033）

    /// centerX 0.5、centerY 0.6、w 0.2、h 0.15 的框；1000×2000 影像、容器 100×200。
    /// plateSelection 直徑 = max(0.2×1000, 0.15×2000) = 300px；view 圈心 (50,80)、view 直徑 30。
    private func sampleDetection() -> DetectedPlate {
        DetectedPlate(centerX: 0.5, centerY: 0.6, width: 0.2, height: 0.15, confidence: 0.8)
    }

    @Test("selectPlate：高亮該框、圈設成框換算的圈，currentSelection 一致")
    func selectPlateSetsCircle() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 100, height: 200))
        let plate = sampleDetection()
        model.selectPlate(plate)
        #expect(model.selectedPlate == plate)
        #expect(model.isCirclePlaced)
        let sel = model.currentSelection()
        #expect(abs(sel.centerX - 0.5) < 1e-9)
        #expect(abs(sel.centerY - 0.6) < 1e-9)
        #expect(abs(sel.diameterPx - 300) < 1e-6)
    }

    @Test("handleTap：點在框內 → 選到該框")
    func handleTapInsideBoxSelects() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 100, height: 200))
        model.receiveDetectedPlates([sampleDetection()])
        model.handleTap(at: CGPoint(x: 50, y: 80)) // 框 view 中心
        #expect(model.selectedPlate == sampleDetection())
        #expect(model.isCirclePlaced)
    }

    @Test("handleTap：點在空白處 → 不選框、改為手動放圈於該點")
    func handleTapEmptyPlacesManually() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 100, height: 200))
        model.receiveDetectedPlates([sampleDetection()])
        model.handleTap(at: CGPoint(x: 90, y: 180)) // 遠離框
        #expect(model.selectedPlate == nil)
        #expect(model.isCirclePlaced)
        #expect(abs(model.circleCenter.x - 90) < 1e-9)
        // 手動圈用預設直徑 18%（顯示寬 100 → 18pt），非框的 25pt。
        #expect(abs(model.circleDiameter - 18) < 1e-9)
    }

    @Test("收到新偵測結果會清掉先前選取")
    func newDetectionClearsSelection() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 100, height: 200))
        model.selectPlate(sampleDetection())
        #expect(model.selectedPlate != nil)
        model.receiveDetectedPlates([])
        #expect(model.selectedPlate == nil)
    }

    @Test("無障礙：置中放置與調整直徑")
    func accessibilityActions() {
        let model = makeModel(width: 1000, height: 2000)
        model.updateContainer(size: CGSize(width: 100, height: 200))
        model.placeCircleAtImageCenter()
        #expect(model.isCirclePlaced)
        #expect(abs(model.circleCenter.x - 50) < 1e-9)
        let before = model.circleDiameter
        model.adjustDiameter(enlarge: true)
        #expect(model.circleDiameter > before)
    }
}
