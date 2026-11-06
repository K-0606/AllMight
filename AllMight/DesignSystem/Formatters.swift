import Foundation

/// 顯示用數字格式化集中在此（見 .claude/rules/swiftui-app.md、ui-text）。
/// 速度 2 位小數、cm 1 位、% 1 位、秒 2 位等結果頁格式在 M5 補上；
/// 這裡先放影片設定需要的重量與直徑。數字與單位之間空一格。
enum Formatters {
    private static func number(_ value: Double, maxFractionDigits: Int) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...maxFractionDigits)))
    }

    /// 重量，kg。0.5 的整數顯示為整數，其餘顯示 1 位小數：`200 kg`、`97.5 kg`。
    static func weightKg(_ kg: Double) -> String {
        "\(number(kg, maxFractionDigits: 1)) kg"
    }

    /// 槓片直徑，cm：`45 cm`。
    static func diameterCm(_ cm: Double) -> String {
        "\(number(cm, maxFractionDigits: 0)) cm"
    }

    /// 時間，`m:ss`（剪輯時間軸用）。無條件捨去秒數，讓並排的起、訖、長度彼此一致。
    static func timecode(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
