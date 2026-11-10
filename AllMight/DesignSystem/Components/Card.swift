import SwiftUI

/// 深灰圓角容器；標題列可帶 SF Symbol 與 ⓘ 說明按鈕（見 skill `swiftui-screens` §3）。
struct Card<Content: View>: View {
    var title: LocalizedStringKey?
    var systemImage: String?
    var onInfo: (() -> Void)?
    @ViewBuilder var content: Content

    init(
        title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        onInfo: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.onInfo = onInfo
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            if title != nil || systemImage != nil || onInfo != nil {
                HStack(spacing: Theme.Space.s) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(Theme.Color.accent)
                    }
                    if let title {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Theme.Color.textPrimary)
                    }
                    Spacer(minLength: 0)
                    if let onInfo {
                        InfoButton(action: onInfo)
                    }
                }
            }
            content
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

/// 圓形資訊（ⓘ）按鈕，開啟指標說明。
struct InfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .accessibilityLabel("說明")
    }
}

#Preview {
    Card(title: "摘要", systemImage: "figure.strengthtraining.traditional", onInfo: {}) {
        Text("200 kg × 3 · RPE 6")
            .foregroundStyle(Theme.Color.textPrimary)
    }
    .padding()
    .background(Theme.Color.background)
    .preferredColorScheme(.dark)
}
