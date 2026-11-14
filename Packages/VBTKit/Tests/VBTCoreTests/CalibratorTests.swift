import Testing
import Foundation
@testable import VBTCore

/// 比例尺與位置換算測試（docs/ALGORITHMS.md §1–2）。
@Suite("校正")
struct CalibratorTests {
    let tol = 1e-9

    @Test("比例尺：45 cm 槓片、450 px 圓圈 → 0.001 m/px")
    func scaleBasic() {
        let sel = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)
        let s = Calibrator.scale(plateDiameterCm: 45, selection: sel)
        #expect(abs(s - 0.001) < tol)
    }

    @Test("直徑為 0 時比例尺回傳 0（不除以零）")
    func scaleZeroDiameter() {
        let sel = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 0)
        #expect(Calibrator.scale(plateDiameterCm: 45, selection: sel) == 0)
    }

    @Test("垂直位移換算：正規化 0.1 的上移對應已知公尺值")
    func verticalDisplacement() {
        // 比例尺 0.001 m/px、heightPx 1920 → 全高 1.92 m。
        // 正規化 y 從 0.3 上升到 0.4（Δ0.1）→ 0.1 × 1920 × 0.001 = 0.192 m。
        let sel = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)
        let geo = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
        let samples = [
            TrackSample(time: 0, x: 0.5, y: 0.3, confidence: 0.9),
            TrackSample(time: 0.1, x: 0.5, y: 0.4, confidence: 0.9),
        ]
        let out = Calibrator.calibrate(samples: samples, selection: sel, geometry: geo, plateDiameterCm: 45)
        #expect(abs(out[0].y - 0) < tol)
        #expect(abs(out[1].y - 0.192) < tol)
    }

    @Test("y 向上為正：正規化 y 增加對應公尺位置增加")
    func upwardIsPositive() {
        let sel = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)
        let geo = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
        let samples = [
            TrackSample(time: 0, x: 0.5, y: 0.2, confidence: 0.9),
            TrackSample(time: 0.1, x: 0.5, y: 0.5, confidence: 0.9),
        ]
        let out = Calibrator.calibrate(samples: samples, selection: sel, geometry: geo, plateDiameterCm: 45)
        #expect(out[1].y > 0)
    }

    @Test("水平位移用 widthPx 換算、保留信心")
    func horizontalAndConfidence() {
        let sel = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)
        let geo = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
        let samples = [
            TrackSample(time: 0, x: 0.5, y: 0.5, confidence: 0.8),
            TrackSample(time: 0.1, x: 0.6, y: 0.5, confidence: 0.2),
        ]
        let out = Calibrator.calibrate(samples: samples, selection: sel, geometry: geo, plateDiameterCm: 45)
        // 0.1 × 1080 × 0.001 = 0.108 m
        #expect(abs(out[1].x - 0.108) < tol)
        #expect(out[1].confidence == 0.2)
    }

    @Test("空輸入回傳空陣列")
    func emptyInput() {
        let sel = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)
        let geo = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)
        let out = Calibrator.calibrate(samples: [], selection: sel, geometry: geo, plateDiameterCm: 45)
        #expect(out.isEmpty)
    }

    // MARK: - scaleMismatch（§1 比例尺差異警告）

    /// widthPx 1080、圈直徑 450 px → 相符的正規化框寬約 450/1080 = 0.417。
    let mismatchSel = PlateSelection(centerX: 0.5, centerY: 0.5, diameterPx: 450)
    let mismatchGeo = VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60)

    func boxSamples(boxWidth: Double?, count: Int) -> [TrackSample] {
        (0..<count).map { TrackSample(time: Double($0) * 0.016, x: 0.5, y: 0.5, confidence: 0.9, boxWidth: boxWidth) }
    }

    @Test("scaleMismatch：框寬中位數與圈直徑差 > 25% → 警告")
    func scaleMismatchTriggers() {
        // 框寬 0.25 → 270 px，圈 450 px，相對差 0.4 > 0.25。
        #expect(Calibrator.scaleMismatch(samples: boxSamples(boxWidth: 0.25, count: 20),
                                         selection: mismatchSel, geometry: mismatchGeo))
    }

    @Test("scaleMismatch：框寬與圈接近 → 不警告")
    func scaleMismatchWithinTolerance() {
        // 框寬 0.41 → 442.8 px，相對差 ~0.016 < 0.25。
        #expect(!Calibrator.scaleMismatch(samples: boxSamples(boxWidth: 0.41, count: 20),
                                          selection: mismatchSel, geometry: mismatchGeo))
    }

    @Test("scaleMismatch：升級前舊樣本（無框寬）不警告")
    func scaleMismatchNoBoxWidth() {
        #expect(!Calibrator.scaleMismatch(samples: boxSamples(boxWidth: nil, count: 20),
                                          selection: mismatchSel, geometry: mismatchGeo))
    }

    @Test("scaleMismatch：帶框寬樣本太少 → 不警告")
    func scaleMismatchTooFewSamples() {
        #expect(!Calibrator.scaleMismatch(samples: boxSamples(boxWidth: 0.25, count: 5),
                                          selection: mismatchSel, geometry: mismatchGeo))
    }

    @Test("scaleMismatch：恰好 = minSamples（10）時仍判斷")
    func scaleMismatchAtMinSamples() {
        #expect(Calibrator.scaleMismatch(samples: boxSamples(boxWidth: 0.25, count: 10),
                                         selection: mismatchSel, geometry: mismatchGeo))
    }

    @Test("scaleMismatch：相對差恰好 = 門檻（0.25）時不警告（用嚴格大於）")
    func scaleMismatchExactlyAtThreshold() {
        // 框寬 px = diameterPx × (1 − 0.25) = 337.5 → 正規化 337.5 / 1080。相對差正好 0.25，不觸發。
        let boxWidth = (450.0 * 0.75) / 1080.0
        #expect(!Calibrator.scaleMismatch(samples: boxSamples(boxWidth: boxWidth, count: 20),
                                          selection: mismatchSel, geometry: mismatchGeo))
    }
}
