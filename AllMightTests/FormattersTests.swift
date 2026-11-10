import Foundation
import Testing
@testable import AllMight

/// 結果頁顯示格式（PRD §3.8）：速度 2 位小數、cm 1 位、% 1 位、秒 2 位；輸入為 SI。
@MainActor
struct FormattersTests {

    @Test("速度 2 位小數，與單位空一格")
    func velocity() {
        #expect(Formatters.velocity(0.28) == "0.28 m/s")
        #expect(Formatters.velocity(0.2) == "0.20 m/s")
        #expect(Formatters.velocity(1.5) == "1.50 m/s")
    }

    @Test("公尺換算 cm，1 位小數")
    func centimeters() {
        #expect(Formatters.centimeters(0.424) == "42.4 cm")
        #expect(Formatters.centimeters(0.5) == "50.0 cm")
    }

    @Test("秒 2 位小數")
    func seconds() {
        #expect(Formatters.seconds(0.4) == "0.40 s")
        #expect(Formatters.seconds(1.234) == "1.23 s")
    }

    @Test("比例轉百分比，1 位小數，%前不空格")
    func percent() {
        #expect(Formatters.percent(0.143) == "14.3%")
        #expect(Formatters.percent(0.5) == "50.0%")
    }

    @Test("相對變化加箭頭：下降↓、上升↑、零±")
    func signedPercent() {
        #expect(Formatters.signedPercent(-0.11) == "↓11.0%")
        #expect(Formatters.signedPercent(0.032) == "↑3.2%")
        #expect(Formatters.signedPercent(0) == "±0.0%")
    }
}
