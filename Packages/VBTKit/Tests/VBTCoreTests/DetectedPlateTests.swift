import Testing
import Foundation
@testable import VBTCore

/// 偵測框幾何測試（docs/ALGORITHMS.md §9、DECISIONS D-033）。純值、合成框、可重現。
@Suite("偵測框幾何")
struct DetectedPlateTests {
    func plate(_ cx: Double, _ cy: Double, _ w: Double, _ h: Double, conf: Double = 0.8) -> DetectedPlate {
        DetectedPlate(centerX: cx, centerY: cy, width: w, height: h, confidence: conf)
    }

    @Test("contains：點在框內/外/邊界")
    func containsPoint() {
        let p = plate(0.5, 0.5, 0.2, 0.2) // x∈[0.4,0.6], y∈[0.4,0.6]
        #expect(p.contains(x: 0.5, y: 0.5))
        #expect(p.contains(x: 0.6, y: 0.6)) // 邊界算在內
        #expect(!p.contains(x: 0.65, y: 0.5))
        #expect(!p.contains(x: 0.5, y: 0.39))
    }

    @Test("換算 PlateSelection：中心直接沿用、直徑取框高（高 0.15×1920 = 288px）")
    func plateSelectionConversion() {
        let geo = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
        let sel = plate(0.5, 0.6, 0.2, 0.15).plateSelection(geometry: geo)
        #expect(abs(sel.centerX - 0.5) < 1e-9)
        #expect(abs(sel.centerY - 0.6) < 1e-9)
        #expect(abs(sel.diameterPx - 288) < 1e-6)
    }

    @Test("寬 > 高時直徑仍取框高（厚片/斜角寬被灌水 → 用高才準）")
    func plateSelectionUsesHeightNotWidth() {
        let geo = VideoGeometry(widthPx: 1000, heightPx: 2000, nominalFPS: 60)
        // 寬 0.4×1000 = 400px、高 0.1×2000 = 200px；應取框高 200，而非寬/max 400。
        let sel = plate(0.5, 0.5, 0.4, 0.1).plateSelection(geometry: geo)
        #expect(abs(sel.diameterPx - 200) < 1e-6)
    }

    @Test("select：點擊落在單一框內 → 回該框")
    func selectSingle() {
        let plates = [plate(0.3, 0.3, 0.2, 0.2), plate(0.7, 0.7, 0.2, 0.2)]
        let picked = try! #require(DetectedPlate.select(tapX: 0.72, tapY: 0.68, from: plates))
        #expect(abs(picked.centerX - 0.7) < 1e-9)
    }

    @Test("select：點擊落在兩個重疊框內 → 回中心較近者")
    func selectNearestWhenOverlap() {
        let a = plate(0.50, 0.50, 0.4, 0.4) // 大框
        let b = plate(0.60, 0.60, 0.3, 0.3) // 另一框，中心離點擊近
        let picked = try! #require(DetectedPlate.select(tapX: 0.58, tapY: 0.58, from: [a, b]))
        #expect(abs(picked.centerX - 0.60) < 1e-9) // b 較近
    }

    @Test("select：兩框等距包含點擊 → 取先出現者（呼叫端已依信心遞減排序）")
    func selectEquidistantKeepsFirst() {
        // 點擊 (0.5,0.5) 到兩框中心等距；偵測器回傳已按信心排序，先出現＝信心高者。
        let high = plate(0.45, 0.5, 0.3, 0.3, conf: 0.9)
        let low = plate(0.55, 0.5, 0.3, 0.3, conf: 0.6)
        let picked = try! #require(DetectedPlate.select(tapX: 0.5, tapY: 0.5, from: [high, low]))
        #expect(picked == high)
    }

    @Test("select：點擊不在任何框內 → nil（退回手動）")
    func selectNoneReturnsNil() {
        let plates = [plate(0.3, 0.3, 0.2, 0.2)]
        #expect(DetectedPlate.select(tapX: 0.9, tapY: 0.9, from: plates) == nil)
    }

    @Test("select：空偵測 → nil")
    func selectEmpty() {
        #expect(DetectedPlate.select(tapX: 0.5, tapY: 0.5, from: []) == nil)
    }
}
