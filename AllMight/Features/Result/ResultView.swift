import SwiftUI
import SwiftData
import VBTCore

/// 結果頁（PRD §3.8）：影片播放器（疊槓鈴軌跡線）、組別摘要、4 格關鍵指標、次數列表、速度曲線。
///
/// 「新分析」與「歷史重看」共用：資料來自 `ResultContext`（已存紀錄或剛分析完）。
/// 可編輯重量與 RPE（只改中繼資料、不重算，見 DECISIONS D-030）。
struct ResultView: View {
    let context: ResultContext
    @Environment(\.modelContext) private var modelContext
    /// 反應式盯著本頁對應的紀錄是否還在；被刪（含在歷史分頁刪同一筆）時會變空，用來切到「已刪除」狀態。
    @Query private var records: [WorkoutSet]
    @State private var model: ResultModel
    @State private var selectedInfo: MetricInfo?
    @State private var editing = false
    // 可編輯的中繼資料：以 context 的值起始，編輯後即時反映並寫回紀錄。
    @State private var loadKg: Double
    @State private var rpe: Double?
    @State private var isWarmup: Bool

    init(context: ResultContext) {
        self.context = context
        _model = State(wrappedValue: ResultModel(context: context))
        _loadKg = State(initialValue: context.loadKg)
        _rpe = State(initialValue: context.rpe)
        _isWarmup = State(initialValue: context.isWarmup)
        // 只追蹤已存檔（有 recordID）的那一筆；未存檔則用永不符合的條件（不視為已刪除）。
        if let recordID = context.recordID {
            _records = Query(filter: #Predicate<WorkoutSet> { $0.id == recordID })
        } else {
            _records = Query(filter: #Predicate<WorkoutSet> { _ in false })
        }
    }

    /// 本頁的紀錄原本存在、現在卻查不到 → 已被刪除（影片與樣本檔也一併沒了）。
    private var isDeleted: Bool {
        context.recordID != nil && records.isEmpty
    }

    private var analysis: SetAnalysis { context.analysis }
    private var summary: SetSummary { analysis.summary }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.l) {
                if isDeleted {
                    deletedNotice
                }
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
        .onAppear { if !isDeleted { model.start() } }
        .onDisappear { model.stop() }
        .onChange(of: isDeleted) { _, deleted in
            // 被刪除時影片檔已不存在，停止播放器避免空轉。
            if deleted { model.stop() }
        }
        .sheet(item: $selectedInfo) { info in
            MetricInfoSheet(info: info)
        }
        .sheet(isPresented: $editing) {
            EditSetSheet(initialLoadKg: loadKg, initialRPE: rpe, initialIsWarmup: isWarmup) { newLoad, newRPE, newWarmup in
                saveEdits(loadKg: newLoad, rpe: newRPE, isWarmup: newWarmup)
            }
            .preferredColorScheme(.dark)
        }
    }

    /// 寫回編輯後的重量與 RPE（只改中繼資料，不重算；見 DECISIONS D-030）。
    private func saveEdits(loadKg newLoad: Double, rpe newRPE: Double?, isWarmup newWarmup: Bool) {
        loadKg = newLoad
        rpe = newRPE
        isWarmup = newWarmup
        guard let recordID = context.recordID else { return }
        let descriptor = FetchDescriptor<WorkoutSet>(predicate: #Predicate { $0.id == recordID })
        guard let set = try? modelContext.fetch(descriptor).first else { return }
        try? WorkoutStore(modelContext: modelContext).updateMetadata(set, loadKg: newLoad, rpe: newRPE, isWarmup: newWarmup)
    }

    // MARK: - 已刪除提示

    private var deletedNotice: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: "trash")
                .foregroundStyle(Theme.Color.warning)
            Text("這筆紀錄已被刪除，如需要請重新分析。")
                .font(.subheadline)
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surfaceHi, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: - 播放器 + 軌跡線

    @ViewBuilder
    private var player: some View {
        if isDeleted {
            deletedPlayerPlaceholder
        } else {
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
    }

    /// 影片檔已隨紀錄刪除，播放器換成佔位提示（分析數字仍可從記憶體呈現）。
    private var deletedPlayerPlaceholder: some View {
        VStack(spacing: Theme.Space.s) {
            Image(systemName: "video.slash")
                .font(.largeTitle)
                .foregroundStyle(Theme.Color.textSecondary)
            Text("影片已刪除")
                .font(.subheadline)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .background(Color.black, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: - 摘要

    private var summaryCard: some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text(context.exercise.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                    summaryLine
                }
                Spacer()
                // 只有已存檔（有 recordID）且尚未被刪除才顯示編輯；否則編輯無處可寫。
                if context.recordID != nil && !isDeleted {
                    Button("編輯") { editing = true }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Color.accent)
                }
            }
        }
    }

    /// 「200 kg × 3 · RPE 6」／「· 熱身」／不評估時不顯示 RPE。字串走 Text 插值以收進在地化目錄。
    @ViewBuilder
    private var summaryLine: some View {
        HStack(spacing: Theme.Space.xs) {
            Text("\(Formatters.weightKg(loadKg)) × \(summary.repCount)")
            if isWarmup {
                Text("· 熱身")
            } else if let rpe {
                Text("· RPE \(Formatters.rpe(rpe))")
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
            recordID: nil,
            analysis: PreviewData.analysis,
            videoURL: PreviewData.videoURL,
            geometry: PreviewData.geometry,
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
