import SwiftUI
import Charts
import VBTCore

/// 垂直速度曲線（PRD §3.8）：Swift Charts 面積圖，x = 時間（s）、y = 速度（m/s）。
/// 拖曳可看該時間點的速度（`chartXSelection`）。向上為正（向心），向下為負（離心）。
/// 每一下的向心範圍以淡色區塊標出並標籤 R1、R2…（Q11；需相位時間，舊紀錄無此欄位則不標）。
struct VelocityChart: View {
    let series: KinematicSeries
    /// 每一下的指標；用其向心相位的起訖時間標示範圍。預設空陣列（不標範圍）。
    var reps: [RepMetrics] = []
    @State private var selectedTime: Double?

    private struct Point: Identifiable {
        let id: Int
        let time: Double
        let velocity: Double
    }

    /// 一下的向心時間範圍（供範圍標示）。只有帶相位時間的紀錄才有。
    private struct RepRange: Identifiable {
        let id: Int
        let start: Double
        let end: Double
    }

    private var points: [Point] {
        let count = min(series.time.count, series.velocity.count)
        return (0..<count).map { Point(id: $0, time: series.time[$0], velocity: series.velocity[$0]) }
    }

    /// 每一下的向心範圍（R1、R2…）；缺相位時間（升級前的舊紀錄）時為空。
    private var repRanges: [RepRange] {
        reps.compactMap { rep in
            guard let start = rep.concentric.startTime, let end = rep.concentric.endTime, end > start else {
                return nil
            }
            return RepRange(id: rep.index, start: start, end: end)
        }
    }

    /// 最接近拖曳時間的取樣點。
    private var selectedPoint: Point? {
        guard let selectedTime, !points.isEmpty else { return nil }
        return points.min { abs($0.time - selectedTime) < abs($1.time - selectedTime) }
    }

    /// 向心（向上）峰值速度，供 VoiceOver 文字替代。
    private var peakVelocity: Double {
        series.velocity.max() ?? 0
    }

    /// VoiceOver 文字替代：次數、每一下向心範圍（PRD §3.8「標出每一下的範圍」）、峰值速度。
    private var accessibilityText: String {
        guard !repRanges.isEmpty else {
            return "垂直速度曲線，峰值速度 \(Formatters.velocity(peakVelocity))"
        }
        let rangeText = repRanges
            .map { "第 \($0.id) 下 \(Formatters.seconds($0.start)) 至 \(Formatters.seconds($0.end))" }
            .joined(separator: "，")
        return "垂直速度曲線，共 \(repRanges.count) 下，\(rangeText)，峰值速度 \(Formatters.velocity(peakVelocity))"
    }

    var body: some View {
        Chart {
            // 每一下的向心範圍（R1、R2…），畫在面積/曲線之下。
            ForEach(repRanges) { range in
                RectangleMark(
                    xStart: .value("起", range.start),
                    xEnd: .value("訖", range.end)
                )
                .foregroundStyle(Theme.Color.accent.opacity(0.10))
                .annotation(position: .top, alignment: .center, spacing: 0) {
                    Text("R\(range.id)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }

            ForEach(points) { point in
                AreaMark(
                    x: .value("時間", point.time),
                    y: .value("速度", point.velocity)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Color.accent.opacity(0.45), Theme.Color.accent.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("時間", point.time),
                    y: .value("速度", point.velocity)
                )
                .foregroundStyle(Theme.Color.accent)
                .interpolationMethod(.catmullRom)
            }

            if let selectedPoint {
                RuleMark(x: .value("時間", selectedPoint.time))
                    .foregroundStyle(Theme.Color.textSecondary.opacity(0.6))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        Text(Formatters.velocity(selectedPoint.velocity))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.Color.textPrimary)
                            .padding(.horizontal, Theme.Space.s)
                            .padding(.vertical, Theme.Space.xs)
                            .background(Theme.Color.surfaceHi, in: Capsule())
                    }
                PointMark(
                    x: .value("時間", selectedPoint.time),
                    y: .value("速度", selectedPoint.velocity)
                )
                .foregroundStyle(Theme.Color.accent)
            }
        }
        .chartXSelection(value: $selectedTime)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(Theme.Color.textSecondary.opacity(0.15))
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text("\(Int(seconds))s")
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(Theme.Color.textSecondary.opacity(0.15))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.formatted(.number.precision(.fractionLength(1))))
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
            }
        }
        .frame(height: 200)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }
}

#Preview {
    VelocityChart(series: PreviewData.series, reps: PreviewData.analysis.reps)
        .padding()
        .background(Theme.Color.background)
        .preferredColorScheme(.dark)
}
