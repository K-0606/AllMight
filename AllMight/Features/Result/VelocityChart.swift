import SwiftUI
import Charts
import VBTCore

/// 垂直速度曲線（PRD §3.8）：Swift Charts 面積圖，x = 時間（s）、y = 速度（m/s）。
/// 拖曳可看該時間點的速度（`chartXSelection`）。向上為正（向心），向下為負（離心）。
struct VelocityChart: View {
    let series: KinematicSeries
    @State private var selectedTime: Double?

    private struct Point: Identifiable {
        let id: Int
        let time: Double
        let velocity: Double
    }

    private var points: [Point] {
        let count = min(series.time.count, series.velocity.count)
        return (0..<count).map { Point(id: $0, time: series.time[$0], velocity: series.velocity[$0]) }
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

    var body: some View {
        Chart {
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
        .accessibilityLabel("垂直速度曲線，峰值速度 \(Formatters.velocity(peakVelocity))")
    }
}

#Preview {
    VelocityChart(series: PreviewData.series)
        .padding()
        .background(Theme.Color.background)
        .preferredColorScheme(.dark)
}
