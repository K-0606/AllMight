import SwiftUI

/// RPE 選擇彈窗（PRD §3.7）：6–10（含 .5）、「熱身」、「跳過」。
///
/// 回傳 `(rpe, isWarmup)`：選數字 → `(值, false)`；熱身 → `(nil, true)`；跳過 → `(nil, false)`。
struct RPEPickerSheet: View {
    let onComplete: (_ rpe: Double?, _ isWarmup: Bool) -> Void

    private let options: [Double] = [6, 7, 7.5, 8, 8.5, 9, 9.5, 10]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Space.m), count: 4)

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            VStack(spacing: Theme.Space.xs) {
                Text("評估用力程度")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("RPE 代表這一組的主觀用力程度（Rate of Perceived Exertion）")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: columns, spacing: Theme.Space.m) {
                ForEach(options, id: \.self) { value in
                    chip(Formatters.rpe(value)) { onComplete(value, false) }
                }
            }

            HStack(spacing: Theme.Space.m) {
                chip("熱身") { onComplete(nil, true) }
                chip("跳過", tint: Theme.Color.textSecondary) { onComplete(nil, false) }
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity)
        .background(Theme.Color.background)
        .presentationDetents([.medium])
    }

    private func chip(_ title: String, tint: Color = Theme.Color.accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.m)
                .background(Theme.Color.surfaceHi, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(tint.opacity(0.6), lineWidth: 1)
                )
        }
        .accessibilityLabel(title == "熱身" || title == "跳過" ? "\(title)" : "RPE \(title)")
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            RPEPickerSheet { _, _ in }
                .preferredColorScheme(.dark)
        }
}
