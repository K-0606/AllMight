import SwiftUI
import VBTCore

/// 首頁：兩個分頁「訓練」與「歷史」。
/// M0 只放入口與空狀態；實際導覽（影片設定、剪輯、結果、歷史內容）在之後的里程碑接上。
struct HomeView: View {
    var body: some View {
        TabView {
            TrainingTab()
                .tabItem {
                    Label("訓練", systemImage: "figure.strengthtraining.traditional")
                }

            HistoryTab()
                .tabItem {
                    Label("歷史", systemImage: "clock.arrow.circlepath")
                }
        }
        .tint(Theme.Color.accent)
    }
}

/// 「訓練」分頁的導覽路由。
enum TrainingRoute: Hashable {
    case setup
    case trim(VideoClip)
    case plateSelect(VideoClip, trimStartSeconds: Double, trimEndSeconds: Double)
    case trackingPreview(VideoClip, trimStartSeconds: Double, trimEndSeconds: Double, selection: PlateSelection)
    case analysis(VideoClip, trimStartSeconds: Double, trimEndSeconds: Double, selection: PlateSelection)
    case result(ResultContext)
}

/// 「訓練」分頁入口：影片分析大卡片與「拍攝建議」次要入口。
/// 點影片分析 → 影片設定 → 剪輯（「拍攝建議」頁在 M7 接上）。
private struct TrainingTab: View {
    @State private var path: [TrainingRoute] = []
    @State private var setupModel = VideoSetupModel()
    /// 分析成功後、選 RPE 前的暫存；觸發 RPE sheet。
    @State private var pendingRPE: PendingAnalysis?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.Color.background.ignoresSafeArea()

                VStack(spacing: Theme.Space.l) {
                    Button {
                        path.append(.setup)
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            Image(systemName: "video.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.Color.accent)
                            Text("影片分析")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Theme.Color.textPrimary)
                            Text("匯入已錄好的影片進行分析")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Space.xl)
                        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    }
                    .buttonStyle(.plain)

                    Button {
                        // M7：導向拍攝建議頁。
                    } label: {
                        Text("拍攝建議")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                    }

                    Spacer()
                }
                .padding(Theme.Space.l)
            }
            .navigationTitle("訓練")
            .navigationDestination(for: TrainingRoute.self) { route in
                switch route {
                case .setup:
                    VideoSetupView(model: setupModel) { clip in
                        path.append(.trim(clip))
                    }
                case .trim(let clip):
                    TrimView(clip: clip) { start, end in
                        path.append(.plateSelect(clip, trimStartSeconds: start, trimEndSeconds: end))
                    }
                case let .plateSelect(clip, start, end):
                    PlateSelectView(
                        clip: clip,
                        trimStartSeconds: start,
                        trimEndSeconds: end,
                        onLocked: { selection in
                            path.append(.trackingPreview(clip, trimStartSeconds: start, trimEndSeconds: end, selection: selection))
                        },
                        onReselect: { if !path.isEmpty { path.removeLast() } }
                    )
                case let .trackingPreview(clip, start, end, selection):
                    TrackingPreviewView(
                        clip: clip,
                        trimStartSeconds: start,
                        trimEndSeconds: end,
                        selection: selection,
                        onStartAnalysis: {
                            path.append(.analysis(clip, trimStartSeconds: start, trimEndSeconds: end, selection: selection))
                        }
                    )
                case let .analysis(clip, start, end, selection):
                    AnalysisProgressView(
                        clip: clip,
                        trimStartSeconds: start,
                        trimEndSeconds: end,
                        selection: selection,
                        exercise: setupModel.exercise,
                        plateDiameterCm: setupModel.plateDiameterCm,
                        onFinished: { analysis in
                            pendingRPE = PendingAnalysis(
                                analysis: analysis,
                                clip: clip,
                                trimStartSeconds: start,
                                trimEndSeconds: end,
                                selection: selection,
                                exercise: setupModel.exercise,
                                loadKg: setupModel.loadKg
                            )
                        },
                        onCancel: { popLast(2) },          // 回點選槓片（PRD §3.6）
                        onReselectPlate: { popLast(2) },   // 回點選槓片
                        onReclip: { popLast(3) }           // 回剪輯片段
                    )
                case let .result(context):
                    ResultView(context: context)
                }
            }
            .sheet(item: $pendingRPE) { pending in
                RPEPickerSheet { rpe, isWarmup in
                    let context = ResultContext(
                        analysis: pending.analysis,
                        clip: pending.clip,
                        trimStartSeconds: pending.trimStartSeconds,
                        trimEndSeconds: pending.trimEndSeconds,
                        selection: pending.selection,
                        exercise: pending.exercise,
                        loadKg: pending.loadKg,
                        rpe: rpe,
                        isWarmup: isWarmup
                    )
                    pendingRPE = nil
                    // 以結果頁取代分析中頁：移除 analysis，推入 result。
                    if !path.isEmpty { path.removeLast() }
                    path.append(.result(context))
                }
                // 必須明確選一項（含「跳過」）才離開；避免滑掉 sheet 卡在分析中頁。
                .interactiveDismissDisabled()
            }
        }
    }

    /// 從導覽堆疊尾端移除最多 `count` 個路由（用於錯誤/取消時導回前面步驟）。
    private func popLast(_ count: Int) {
        let n = min(count, path.count)
        path.removeLast(n)
    }
}

/// 「歷史」分頁：M0 顯示空狀態。
private struct HistoryTab: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.background.ignoresSafeArea()

                VStack(spacing: Theme.Space.m) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Text("還沒有紀錄。到「訓練」分頁匯入第一段影片。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.Space.xl)
            }
            .navigationTitle("歷史")
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
