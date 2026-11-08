import Testing
import Foundation
import CoreGraphics
import VBTCore
@testable import VBTVision

/// 影片級端對端準確度（skill accuracy-check）：合成「半正弦一下」影片 → 真實 Vision 追蹤
/// （`TrackingRunner`）→ M3 運動學管線（`Kinematics`），在已知向心區間斷言 MV/ROM。
///
/// 與 VBTCoreTests 的合成**訊號**測試互補：那邊用模型化高斯雜訊，這邊用真實
/// `VNTrackObjectRequest` 的追蹤雜訊（含 ~0.9px 底噪，D-023），驗證校正＋平滑在
/// 真實追蹤輸出上仍達 §8 門檻。次數切分與完整 accuracy-check 表（需 RepSegmenter）留待 M4。
@Suite("運動學影片端對端")
struct KinematicsVideoTests {
    // 影片與物理參數：scale = 45 cm / 110 px ≈ 0.004091 m/px。
    let width = 360, height = 640, fps = 60
    let diameterPx = 110.0
    let plateDiameterCm = 45.0
    let baseYpx = 420.0
    // 半正弦一下：前後停頓 + 向心（上升）+ 離心（下降）。
    let pause = 0.4, concentricDuration = 0.5, eccentricDuration = 0.5, peakVelocity = 0.45

    /// 向心上升、離心下降回到起點的解析位置（公尺，向上為正，起點 0）。
    func positionMeters(_ t: Double) -> Double {
        let Tc = concentricDuration, Te = eccentricDuration
        let Vc = peakVelocity, Ve = peakVelocity * concentricDuration / eccentricDuration
        if t < pause { return 0 }
        let tc = t - pause
        if tc <= Tc { return (Vc * Tc / .pi) * (1 - cos(.pi * tc / Tc)) }
        let te = tc - Tc
        let peak = 2 * Vc * Tc / .pi
        if te <= Te { return peak - (Ve * Te / .pi) * (1 - cos(.pi * te / Te)) }
        return 0
    }

    @Test("合成一下影片經真實追蹤後 MV 誤差 < 0.02 m/s、ROM 誤差 < 1 cm")
    func videoToVelocity() async throws {
        let scale = plateDiameterCm / 100 / diameterPx // m/px
        let total = pause + concentricDuration + eccentricDuration + pause
        let count = Int((total * Double(fps)).rounded(.down)) + 1

        // 建軌跡（轉正後影像、原點左上）：向上為正 → 像素 y 減小。
        let centers = (0..<count).map { i -> CGPoint in
            let t = Double(i) / Double(fps)
            return CGPoint(x: Double(width) / 2, y: baseYpx - positionMeters(t) / scale)
        }

        let video = try await SyntheticPlateVideo.make(
            orientedWidth: width, orientedHeight: height,
            centersPx: centers, diameterPx: diameterPx, fps: fps
        )
        defer { try? FileManager.default.removeItem(at: video.url) }

        let selection = PlateSelection(
            centerX: centers[0].x / Double(width),
            centerY: 1 - centers[0].y / Double(height),
            diameterPx: diameterPx
        )
        let run = try await TrackingRunner().run(
            url: video.url,
            trimStartSeconds: 0,
            trimEndSeconds: total + 0.2,
            selection: selection
        )
        #expect(run.lostAtTime == nil)

        let geometry = VideoGeometry(widthPx: width, heightPx: height, nominalFPS: Double(fps))
        let series = try Kinematics.computeSeries(
            samples: run.samples,
            selection: selection,
            geometry: geometry,
            plateDiameterCm: plateDiameterCm,
            parameters: .standard
        )

        // 已知向心區間 [pause, pause+Tc]，取最近網格索引。
        func nearest(_ target: Double) -> Int {
            var best = 0, bestDiff = Double.greatestFiniteMagnitude
            for (i, t) in series.time.enumerated() where abs(t - target) < bestDiff {
                bestDiff = abs(t - target); best = i
            }
            return best
        }
        let s = nearest(pause)
        let e = nearest(pause + concentricDuration)
        let rom = series.position[e] - series.position[s]
        let mv = rom / (series.time[e] - series.time[s])

        let expectedROM = 2 * peakVelocity * concentricDuration / .pi
        let expectedMV = 2 * peakVelocity / .pi
        #expect(abs(mv - expectedMV) < 0.02, "MV \(mv) vs \(expectedMV)")
        #expect(abs(rom - expectedROM) < 0.01, "ROM \(rom) vs \(expectedROM)")
    }
}
