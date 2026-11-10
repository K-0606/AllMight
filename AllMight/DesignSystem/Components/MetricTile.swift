import SwiftUI

/// 關鍵指標格：數值（含單位）+ 標籤 + 可選 ⓘ 說明（見 skill `swiftui-screens` §3）。
/// 4 格一排用於結果頁關鍵指標（PRD §3.8）。
struct MetricTile: View {
    let label: LocalizedStringKey
    /// 已格式化的數值字串（含單位，如 `0.28 m/s`）。
    let value: String
    var tint: Color = Theme.Color.textPrimary
    var onInfo: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(spacing: Theme.Space.xs) {
                Text(label)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.textSecondary)
                Spacer(minLength: 0)
                if let onInfo {
                    InfoButton(action: onInfo)
                        .font(.caption)
                }
            }
            Text(value)
                .font(Theme.Font.metric)
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.m)
        .background(Theme.Color.surfaceHi, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: Theme.Space.s) {
        MetricTile(label: "動作幅度", value: "42.4 cm", onInfo: {})
        MetricTile(label: "速度損失", value: "14.3%", tint: Theme.Color.warning, onInfo: {})
    }
    .padding()
    .background(Theme.Color.background)
    .preferredColorScheme(.dark)
}
