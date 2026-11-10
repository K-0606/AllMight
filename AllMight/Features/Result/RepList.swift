import SwiftUI
import VBTCore

/// 次數列表（PRD §3.8）：每下一列 `RepRow`，點擊展開看向心／離心細節與與下一下的間隔。
struct RepList: View {
    let reps: [RepMetrics]
    @State private var expanded: Set<Int> = []

    private var maxMeanVelocity: Double {
        reps.map(\.concentric.meanVelocity).max() ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(reps, id: \.index) { rep in
                VStack(spacing: Theme.Space.m) {
                    Button {
                        toggle(rep.index)
                    } label: {
                        HStack(spacing: Theme.Space.s) {
                            RepRow(rep: rep, maxMeanVelocity: maxMeanVelocity)
                            Image(systemName: expanded.contains(rep.index) ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if expanded.contains(rep.index) {
                        detail(for: rep)
                    }
                }
                .padding(.vertical, Theme.Space.m)

                if rep.index != reps.last?.index {
                    Divider().overlay(Theme.Color.textSecondary.opacity(0.15))
                }
            }
        }
    }

    private func toggle(_ index: Int) {
        if expanded.contains(index) {
            expanded.remove(index)
        } else {
            expanded.insert(index)
        }
    }

    @ViewBuilder
    private func detail(for rep: RepMetrics) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            section("向心") {
                DetailRow(label: "時間", value: Formatters.seconds(rep.concentric.duration))
                DetailRow(label: "峰值速度", value: Formatters.velocity(rep.concentric.peakVelocity))
                DetailRow(label: "平均速度（MV）", value: Formatters.velocity(rep.concentric.meanVelocity))
                DetailRow(label: "平均推進速度（MPV）", value: Formatters.velocity(rep.mpv))
                DetailRow(label: "動作幅度（ROM）", value: Formatters.centimeters(rep.concentric.displacement))
            }

            if let eccentric = rep.eccentric {
                section("離心") {
                    DetailRow(label: "時間", value: Formatters.seconds(eccentric.duration))
                    DetailRow(label: "峰值速度", value: Formatters.velocity(eccentric.peakVelocity))
                    DetailRow(label: "平均速度", value: Formatters.velocity(eccentric.meanVelocity))
                    if rep.concentric.meanVelocity > 0 {
                        DetailRow(
                            label: "離心／向心平均速度比",
                            value: Formatters.percent(eccentric.meanVelocity / rep.concentric.meanVelocity)
                        )
                    }
                }
            }

            if let rest = rep.restAfter {
                DetailRow(label: "與下一下的間隔", value: Formatters.seconds(rest))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.m)
        .background(Theme.Color.surfaceHi, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.Color.accent)
        content()
    }
}

/// 展開細節的一列：標籤（左）與數值（右，等寬數字）。
private struct DetailRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer(minLength: Theme.Space.m)
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        RepList(reps: PreviewData.analysis.reps)
            .padding()
    }
    .background(Theme.Color.background)
    .preferredColorScheme(.dark)
}
