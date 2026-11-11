import SwiftUI

/// 編輯一組紀錄的重量與 RPE（PRD §3.8「編輯」）。
///
/// 只編輯中繼資料；重量與 RPE 不影響分析數值（比例尺用槓片直徑、不是重量），故不重算
/// （見 DECISIONS D-030）。回傳新的 `(loadKg, rpe, isWarmup)`。
struct EditSetSheet: View {
    let initialLoadKg: Double
    let initialRPE: Double?
    let initialIsWarmup: Bool
    let onSave: (_ loadKg: Double, _ rpe: Double?, _ isWarmup: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var loadKg: Double
    @State private var rpe: Double?
    @State private var isWarmup: Bool

    private let rpeOptions: [Double] = [6, 7, 7.5, 8, 8.5, 9, 9.5, 10]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Space.s), count: 4)

    init(
        initialLoadKg: Double,
        initialRPE: Double?,
        initialIsWarmup: Bool,
        onSave: @escaping (_ loadKg: Double, _ rpe: Double?, _ isWarmup: Bool) -> Void
    ) {
        self.initialLoadKg = initialLoadKg
        self.initialRPE = initialRPE
        self.initialIsWarmup = initialIsWarmup
        self.onSave = onSave
        _loadKg = State(initialValue: initialLoadKg)
        _rpe = State(initialValue: initialRPE)
        _isWarmup = State(initialValue: initialIsWarmup)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    weightSection
                    rpeSection
                }
                .padding(Theme.Space.xl)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationTitle("編輯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        onSave(loadKg, isWarmup ? nil : rpe, isWarmup)
                        dismiss()
                    }
                }
            }
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("重量")
                .font(.headline)
                .foregroundStyle(Theme.Color.textPrimary)
            Stepper(value: $loadKg, in: 1...500, step: 0.5) {
                Text(Formatters.weightKg(loadKg))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(Theme.Color.textPrimary)
            }
            .accessibilityValue(Formatters.weightKg(loadKg))
        }
    }

    private var rpeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("用力程度（RPE）")
                .font(.headline)
                .foregroundStyle(Theme.Color.textPrimary)
            LazyVGrid(columns: columns, spacing: Theme.Space.s) {
                ForEach(rpeOptions, id: \.self) { value in
                    chip(
                        Formatters.rpe(value),
                        selected: !isWarmup && rpe == value
                    ) {
                        isWarmup = false
                        rpe = value
                    }
                }
            }
            HStack(spacing: Theme.Space.s) {
                chip("熱身", selected: isWarmup) {
                    isWarmup = true
                    rpe = nil
                }
                chip("不評估", selected: !isWarmup && rpe == nil) {
                    isWarmup = false
                    rpe = nil
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.monospacedDigit())
                .foregroundStyle(selected ? Theme.Color.background : Theme.Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.m)
                .background(
                    selected ? Theme.Color.accent : Theme.Color.surfaceHi,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.button)
                )
        }
        .accessibilityLabel(title == "熱身" || title == "不評估" ? "\(title)" : "RPE \(title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            EditSetSheet(initialLoadKg: 200, initialRPE: 8, initialIsWarmup: false) { _, _, _ in }
                .preferredColorScheme(.dark)
        }
}
