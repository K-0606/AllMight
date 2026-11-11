import Foundation

/// 顯示用數字格式化集中在此（見 .claude/rules/swiftui-app.md、ui-text）。
/// 結果頁格式（PRD §3.8）：速度 2 位小數、cm 1 位、% 1 位、秒 2 位。
/// 數字與單位之間空一格（%除外，依中文慣例不空格）。輸入一律 SI（公尺、秒、m/s），由此換算顯示單位。
enum Formatters {
    /// 固定用小數點（`.`）作小數分隔，與 PRD 範例一致、不受裝置 locale 影響。
    private static let locale = Locale(identifier: "en_US_POSIX")

    private static func number(_ value: Double, maxFractionDigits: Int) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...maxFractionDigits)).locale(locale))
    }

    /// 固定小數位（不修剪尾端 0），結果頁數值用。
    private static func fixed(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(fractionDigits)).locale(locale))
    }

    /// 重量，kg。0.5 的整數顯示為整數，其餘顯示 1 位小數：`200 kg`、`97.5 kg`。
    static func weightKg(_ kg: Double) -> String {
        "\(number(kg, maxFractionDigits: 1)) kg"
    }

    /// 槓片直徑，cm：`45 cm`。
    static func diameterCm(_ cm: Double) -> String {
        "\(number(cm, maxFractionDigits: 0)) cm"
    }

    /// RPE：整數顯示整數、.5 顯示 1 位小數，固定用小數點：`6`、`7.5`。
    /// 全 App 共用，避免不同頁面因 locale 差異出現 `7,5`／`7.5` 不一致。
    static func rpe(_ value: Double) -> String {
        number(value, maxFractionDigits: 1)
    }

    /// 時間，`m:ss`（剪輯時間軸用）。無條件捨去秒數，讓並排的起、訖、長度彼此一致。
    static func timecode(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - 結果頁（PRD §3.8）

    /// 速度，m/s，2 位小數：`0.28 m/s`。
    static func velocity(_ metersPerSecond: Double) -> String {
        "\(fixed(metersPerSecond, fractionDigits: 2)) m/s"
    }

    /// 動作幅度，由公尺換算成 cm，1 位小數：`42.4 cm`。
    static func centimeters(_ meters: Double) -> String {
        "\(fixed(meters * 100, fractionDigits: 1)) cm"
    }

    /// 相位時間，秒，2 位小數：`0.42 s`。
    static func seconds(_ value: Double) -> String {
        "\(fixed(value, fractionDigits: 2)) s"
    }

    /// 比例（0.143）顯示為百分比，1 位小數：`14.3%`（%前不空格）。
    static func percent(_ ratio: Double) -> String {
        "\(fixed(ratio * 100, fractionDigits: 1))%"
    }

    /// 相對變化（dropFromFirst／速度損失用）：負值為下降，加上箭頭：`↓11.0%`、`↑3.2%`、`±0.0%`。
    static func signedPercent(_ ratio: Double) -> String {
        let magnitude = fixed(abs(ratio) * 100, fractionDigits: 1)
        let arrow = ratio < 0 ? "↓" : (ratio > 0 ? "↑" : "±")
        return "\(arrow)\(magnitude)%"
    }
}
