import SwiftUI
import SwiftData
import os
import VBTCore
import VBTVision

/// 首頁：兩個分頁「訓練」與「歷史」。
/// M0 只放入口與空狀態；實際導覽（影片設定、剪輯、結果、歷史內容）在之後的里程碑接上。
struct HomeView: View {
    var body: some View {
        TabView {
            TrainingTab()
                .tabItem {
                    Label("訓練", systemImage: "figure.strengthtraining.traditional")
                }

            HistoryView()
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
    private static let logger = Logger(subsystem: "com.kun0606.AllMight", category: "History")

    @Environment(\.modelContext) private var modelContext
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
                        onFinished: { analysis, samples in
                            pendingRPE = PendingAnalysis(
                                analysis: analysis,
                                samples: samples,
                                videoURL: clip.url,
                                geometry: clip.info.geometry,
                                trimStartSeconds: start,
                                trimEndSeconds: end,
                                selection: selection,
                                exercise: setupModel.exercise,
                                loadKg: setupModel.loadKg,
                                plateDiameterCm: setupModel.plateDiameterCm
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
                    let context = saveAndMakeContext(pending: pending, rpe: rpe, isWarmup: isWarmup)
                    pendingRPE = nil
                    // 分析已完成並存檔：把整個堆疊重設成只剩結果頁，讓「返回」回到訓練首頁，
                    // 而不是倒退進已消耗的點選槓片/分析流程（那些頁仍握著影片檔，若該筆被刪會讀不到檔）。
                    path = [.result(context)]
                }
                // 必須明確選一項（含「跳過」）才離開；避免滑掉 sheet 卡在分析中頁。
                .interactiveDismissDisabled()
            }
        }
    }

    /// 選完 RPE 後自動存一組紀錄（含樣本檔），回傳結果頁用的 `ResultContext`（帶 `recordID`）。
    /// 存檔失敗不擋住看結果：記錄錯誤，`recordID` 為 nil（此次不會進歷史、也不能編輯）。
    private func saveAndMakeContext(pending: PendingAnalysis, rpe: Double?, isWarmup: Bool) -> ResultContext {
        var recordID: UUID?
        do {
            let set = try WorkoutStore(modelContext: modelContext).save(
                analysis: pending.analysis,
                samples: pending.samples,
                videoFileName: pending.videoURL.lastPathComponent,
                geometry: pending.geometry,
                selection: pending.selection,
                trimStartSeconds: pending.trimStartSeconds,
                trimEndSeconds: pending.trimEndSeconds,
                exercise: pending.exercise,
                loadKg: pending.loadKg,
                plateDiameterCm: pending.plateDiameterCm,
                rpe: rpe,
                isWarmup: isWarmup
            )
            recordID = set.id
        } catch {
            Self.logger.error("自動儲存失敗：\(error.localizedDescription, privacy: .public)")
            recordID = nil
        }
        return ResultContext(
            recordID: recordID,
            analysis: pending.analysis,
            videoURL: pending.videoURL,
            geometry: pending.geometry,
            trimStartSeconds: pending.trimStartSeconds,
            trimEndSeconds: pending.trimEndSeconds,
            selection: pending.selection,
            exercise: pending.exercise,
            loadKg: pending.loadKg,
            rpe: rpe,
            isWarmup: isWarmup
        )
    }

    /// 從導覽堆疊尾端移除最多 `count` 個路由（用於錯誤/取消時導回前面步驟）。
    private func popLast(_ count: Int) {
        let n = min(count, path.count)
        path.removeLast(n)
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
