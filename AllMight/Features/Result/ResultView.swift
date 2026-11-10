import SwiftUI
import VBTCore

/// 結果頁（PRD §3.8）：影片播放器（疊槓鈴軌跡線）、組別摘要、4 格關鍵指標、次數列表、速度曲線。
///
/// M5 只呈現記憶體中的 `SetAnalysis`，不持久化（儲存為 M6）。
struct ResultView: View {
    let context: ResultContext
    @State private var model: ResultModel
    @State private var selectedInfo: MetricInfo?

    init(context: ResultContext) {
        self.context = context
        _model = State(wrappedValue: ResultModel(context: context))
    }

    private var analysis: SetAnalysis { context.analysis }
    private var summary: SetSummary { analysis.summary }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.l) {
                player
                summaryCard
                metricTiles
                chartCard
                repListCard
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationTitle(context.exercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .sheet(item: $selectedInfo) { info in
            MetricInfoSheet(info: info)
        }
    }

    // MARK: - 播放器 + 軌跡線

    private var player: some View {
        GeometryReader { geo in
            let rect = model.imageRect(containerSize: geo.size)
            ZStack {
                VideoLayerView(player: model.player)
                PolylineShape(points: model.trajectoryPoints(in: rect))
                    .stroke(Theme.Color.accent.opacity(0.8), lineWidth: 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture { model.togglePlayback() }
        }
        .frame(height: 360)
        .background(Color.black, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityLabel("影片片段，疊有槓鈴軌跡線。點一下播放或暫停。")
    }

    // MARK: - 摘要

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text(context.exercise.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                summaryLine
            }
        }
    }

    /// 「200 kg × 3 · RPE 6」／「· 熱身」／跳過時不顯示 RPE。字串走 Text 插值以收進在地化目錄。
    @ViewBuilder
    private var summaryLine: some View {
        HStack(spacing: Theme.Space.xs) {
            Text("\(Formatters.weightKg(context.loadKg)) × \(summary.repCount)")
            if context.isWarmup {
                Text("· 熱身")
            } else if let rpe = context.rpe {
                Text("· RPE \(rpe.formatted(.number.locale(Locale(identifier: "en_US_POSIX"))))")
            }
        }
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(Theme.Color.textSecondary)
    }

    // MARK: - 4 格關鍵指標

    private var metricTiles: some View {
        let columns = [
            GridItem(.flexible(), spacing: Theme.Space.s),
            GridItem(.flexible(), spacing: Theme.Space.s),
        ]
        return LazyVGrid(columns: columns, spacing: Theme.Space.s) {
            MetricTile(label: "動作幅度", value: Formatters.centimeters(summary.meanROM)) {
                selectedInfo = .rom
            }
            MetricTile(label: "峰值速度", value: Formatters.velocity(summary.peakVelocity)) {
                selectedInfo = .peakVelocity
            }
            MetricTile(label: "平均速度", value: Formatters.velocity(summary.meanVelocity)) {
                selectedInfo = .meanVelocity
            }
            MetricTile(
                label: "速度損失",
                value: summary.velocityLoss.map(Formatters.percent) ?? "—",
                tint: (summary.velocityLoss ?? 0) > 0 ? Theme.Color.warning : Theme.Color.textPrimary
            ) {
                selectedInfo = .velocityLoss
            }
        }
    }

    // MARK: - 速度曲線

    private var chartCard: some View {
        Card(title: "速度曲線", systemImage: "waveform.path.ecg") {
            VelocityChart(series: analysis.series)
        }
    }

    // MARK: - 次數列表

    private var repListCard: some View {
        Card(title: "次數", systemImage: "list.number", onInfo: { selectedInfo = .mpv }) {
            RepList(reps: analysis.reps)
        }
    }
}

/// 把一串顯示座標點連成折線（結果頁的槓鈴軌跡線）。
private struct PolylineShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

#Preview {
    NavigationStack {
        ResultView(context: ResultContext(
            analysis: PreviewData.analysis,
            clip: PreviewData.clip,
            trimStartSeconds: 0,
            trimEndSeconds: 6,
            selection: PreviewData.selection,
            exercise: .backSquat,
            loadKg: 200,
            rpe: 6,
            isWarmup: false
        ))
    }
    .preferredColorScheme(.dark)
}
