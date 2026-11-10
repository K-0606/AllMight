import SwiftUI
import VBTCore

/// 次數列表的一列（收合狀態）：`REP n` + 長條（寬度依向心 MV / 本組最大 MV）+ 平均速度
/// + 相對第 1 下的變化（見 skill `swiftui-screens` §3、PRD §3.8）。
///
/// 展開後的向心／離心細節由結果頁的 `RepList` 負責。
struct RepRow: View {
    let rep: RepMetrics
    /// 本組最大的向心平均速度，用來決定長條滿寬的比例。
    let maxMeanVelocity: Double

    private var barFraction: Double {
        guard maxMeanVelocity > 0 else { return 0 }
        return min(1, max(0.05, rep.concentric.meanVelocity / maxMeanVelocity))
    }

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Text("REP \(rep.index)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.Color.textSecondary)
                .frame(width: 64, alignment: .leading)

            GeometryReader { geo in
                Capsule()
                    .fill(Theme.Color.accent)
                    .frame(width: geo.size.width * barFraction)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 10)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.velocity(rep.concentric.meanVelocity))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.Color.textPrimary)
                if let drop = rep.dropFromFirst {
                    Text(Formatters.signedPercent(drop))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(drop < 0 ? Theme.Color.warning : Theme.Color.textSecondary)
                }
            }
            .frame(width: 92, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = ["第 \(rep.index) 下", "平均速度 \(Formatters.velocity(rep.concentric.meanVelocity))"]
        if let drop = rep.dropFromFirst {
            let direction = drop < 0 ? "下降" : "上升"
            parts.append("相對第 1 下\(direction) \(Formatters.percent(abs(drop)))")
        }
        return parts.joined(separator: "，")
    }
}

#Preview {
    VStack(spacing: Theme.Space.m) {
        ForEach(PreviewData.analysis.reps, id: \.index) { rep in
            RepRow(rep: rep, maxMeanVelocity: 0.28)
        }
    }
    .padding()
    .background(Theme.Color.background)
    .preferredColorScheme(.dark)
}
