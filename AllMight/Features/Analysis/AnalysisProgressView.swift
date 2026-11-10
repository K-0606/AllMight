import SwiftUI
import VBTCore

/// 分析中頁（PRD §3.6）：顯示追蹤 / 計算進度與狀態文字，可取消；失敗時顯示對應文字並導回。
struct AnalysisProgressView: View {
    @State private var model: AnalysisModel
    let onFinished: (SetAnalysis) -> Void
    let onCancel: () -> Void
    let onReselectPlate: () -> Void
    let onReclip: () -> Void

    init(
        clip: VideoClip,
        trimStartSeconds: Double,
        trimEndSeconds: Double,
        selection: PlateSelection,
        exercise: Exercise,
        plateDiameterCm: Double,
        onFinished: @escaping (SetAnalysis) -> Void,
        onCancel: @escaping () -> Void,
        onReselectPlate: @escaping () -> Void,
        onReclip: @escaping () -> Void
    ) {
        _model = State(wrappedValue: AnalysisModel(
            clip: clip,
            trimStartSeconds: trimStartSeconds,
            trimEndSeconds: trimEndSeconds,
            selection: selection,
            exercise: exercise,
            plateDiameterCm: plateDiameterCm
        ))
        self.onFinished = onFinished
        self.onCancel = onCancel
        self.onReselectPlate = onReselectPlate
        self.onReclip = onReclip
    }

    var body: some View {
        ZStack {
            Theme.Color.background.ignoresSafeArea()

            switch model.state {
            case .tracking, .analyzing:
                progressContent
            case .failed(let error):
                failureContent(error)
            case .finished:
                // 完成瞬間由 onChange 導向 RPE；此處顯示過場。
                ProgressView().tint(Theme.Color.accent)
            }
        }
        .navigationTitle("分析中")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task { await model.run() }
        .onChange(of: model.state) { _, newState in
            if case .finished(let analysis) = newState {
                onFinished(analysis)
            }
        }
    }

    // MARK: - 進度

    @ViewBuilder
    private var progressContent: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()

            switch model.state {
            case .tracking(let fraction):
                ProgressView(value: fraction)
                    .tint(Theme.Color.accent)
                    .frame(maxWidth: 240)
                Text("追蹤槓片中")
                    .font(.headline)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(Theme.Font.metricLarge)
                    .foregroundStyle(Theme.Color.accent)
            case .analyzing:
                ProgressView()
                    .tint(Theme.Color.accent)
                Text("計算速度中")
                    .font(.headline)
                    .foregroundStyle(Theme.Color.textPrimary)
            default:
                EmptyView()
            }

            Spacer()

            Button("取消", role: .cancel, action: onCancel)
                .font(.headline)
                .foregroundStyle(Theme.Color.textSecondary)
                .padding(.bottom, Theme.Space.xl)
        }
        .padding(Theme.Space.xl)
    }

    // MARK: - 失敗

    @ViewBuilder
    private func failureContent(_ error: AnalysisError) -> some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Theme.Color.warning)
            Text(message(for: error))
                .font(.body)
                .foregroundStyle(Theme.Color.textPrimary)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(primaryActionTitle(for: error)) {
                primaryAction(for: error)()
            }
        }
        .padding(Theme.Space.xl)
    }

    /// PRD §3.6 的錯誤文字。
    private func message(for error: AnalysisError) -> LocalizedStringKey {
        switch error {
        case .trackingLost(let time):
            "槓片在 \(Formatters.timecode(time)) 附近跟丟了，請確認槓片沒有被擋住，再重新點選。"
        case .noRepsDetected:
            "沒有偵測到完整的動作，請確認片段包含整個動作。"
        default:
            "無法分析這段影片，請換一段再試。"
        }
    }

    private func primaryActionTitle(for error: AnalysisError) -> LocalizedStringKey {
        switch error {
        case .trackingLost:
            "重新點選槓片"
        default:
            "重新選擇片段"
        }
    }

    private func primaryAction(for error: AnalysisError) -> () -> Void {
        switch error {
        case .trackingLost:
            onReselectPlate
        default:
            onReclip
        }
    }
}
