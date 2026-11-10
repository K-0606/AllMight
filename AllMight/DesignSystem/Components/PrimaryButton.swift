import SwiftUI

/// 滿版薄荷綠主要按鈕（見 skill `swiftui-screens` §3）。文字用動詞（見 ui-text 規則）。
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isEnabled: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(Theme.Color.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.l)
            .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

#Preview {
    VStack(spacing: Theme.Space.l) {
        PrimaryButton("開始分析", systemImage: "chart.line.uptrend.xyaxis") {}
        PrimaryButton("鎖定並追蹤", isEnabled: false) {}
    }
    .padding()
    .background(Theme.Color.background)
    .preferredColorScheme(.dark)
}
