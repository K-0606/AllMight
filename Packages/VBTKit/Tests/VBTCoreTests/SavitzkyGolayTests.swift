import Testing
import Foundation
@testable import VBTCore

/// Savitzky-Golay 係數、平滑與微分測試（docs/ALGORITHMS.md §4、skill velocity-analysis §2）。
///
/// 關鍵性質：階數 ≤ order 的多項式，平滑後在內部點不變、一階導數等於解析導數。
/// 鏡像邊界對線性訊號處處精確（奇反射保斜率），對二次只在內部精確。
@Suite("Savitzky-Golay")
struct SavitzkyGolayTests {
    let tol = 1e-9

    @Test("視窗長度換算：0.15 s × 60 fps → 9 點、半徑 4")
    func halfWindowFromSeconds() {
        #expect(SavitzkyGolay.halfWindow(windowSeconds: 0.15, fps: 60) == 4)
    }

    @Test("視窗最少 5 點（半徑 2）")
    func halfWindowMinimum() {
        #expect(SavitzkyGolay.halfWindow(windowSeconds: 0.01, fps: 30) == 2)
    }

    @Test("偶數點數進位成奇數")
    func halfWindowRoundsToOdd() {
        // 0.1 × 100 = 10 → 進位成 11 → 半徑 5
        #expect(SavitzkyGolay.halfWindow(windowSeconds: 0.10, fps: 100) == 5)
    }

    @Test("線性訊號平滑後處處不變（含邊界）")
    func linearSmoothExact() {
        let sg = SavitzkyGolay(halfWindow: 4, order: 3)
        let dt = 1.0 / 60
        let a = 0.3, b = 1.7
        let x = (0..<40).map { a + b * (Double($0) * dt) }
        let s = sg.smooth(x)
        for i in 0..<x.count {
            #expect(abs(s[i] - x[i]) < tol)
        }
    }

    @Test("線性訊號一階導數處處等於斜率（含邊界）")
    func linearFirstDerivativeExact() {
        let sg = SavitzkyGolay(halfWindow: 4, order: 3)
        let dt = 1.0 / 60
        let b = 1.7
        let x = (0..<40).map { 0.3 + b * (Double($0) * dt) }
        let v = sg.firstDerivative(x, dt: dt)
        for i in 0..<x.count {
            #expect(abs(v[i] - b) < tol)
        }
    }

    @Test("二次訊號在內部點平滑不變、一階導數等於 b+2ct")
    func quadraticInteriorExact() {
        let sg = SavitzkyGolay(halfWindow: 4, order: 3)
        let dt = 1.0 / 60
        let a = 0.2, b = 1.1, c = -3.4
        let n = 40
        let t = (0..<n).map { Double($0) * dt }
        let x = t.map { a + b * $0 + c * $0 * $0 }
        let s = sg.smooth(x)
        let v = sg.firstDerivative(x, dt: dt)
        let acc = sg.secondDerivative(x, dt: dt)
        // 內部點（視窗完全落在陣列內）才精確
        for i in sg.halfWindow..<(n - sg.halfWindow) {
            #expect(abs(s[i] - x[i]) < 1e-8)
            #expect(abs(v[i] - (b + 2 * c * t[i])) < 1e-7)
            #expect(abs(acc[i] - 2 * c) < 1e-6)
        }
    }

    @Test("對含雜訊的正弦速度訊號，導數誤差在容差內")
    func sineVelocityWithinTolerance() {
        // 位置 p(t) = (A/ω)(1 − cos ωt) → 速度 v = A sin ωt、加速度 a = Aω cos ωt
        let sg = SavitzkyGolay(halfWindow: 4, order: 3)
        let dt = 1.0 / 60
        let n = 120
        let omega = 2 * Double.pi * 1.0 // 1 Hz
        let amp = 0.4
        let t = (0..<n).map { Double($0) * dt }
        let x = t.map { (amp / omega) * (1 - cos(omega * $0)) }
        let v = sg.firstDerivative(x, dt: dt)
        // 檢查內部段（避開邊界）速度誤差
        var maxErr = 0.0
        for i in sg.halfWindow..<(n - sg.halfWindow) {
            let exact = amp * sin(omega * t[i])
            maxErr = max(maxErr, abs(v[i] - exact))
        }
        #expect(maxErr < 0.01)
    }
}
