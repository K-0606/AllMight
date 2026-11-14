import SwiftUI
import VBTCore
import VBTVision

/// 追蹤驗證頁：跑追蹤後重播剪好的片段，把追蹤點（紅）與整條軌跡（線）疊在槓片上，供目視確認追蹤是否正確。
///
/// 這是 M2 之後插入的驗證步驟（非 PRD 畫面）；追蹤引擎與 M4 分析管線共用 `TrackingRunner`。
struct TrackingPreviewView: View {
    @State private var model: TrackingPreviewModel
    /// 使用者確認追蹤正確後，進入正式分析（見 FLOW、ROADMAP M5）。
    let onStartAnalysis: () -> Void

    init(
        clip: VideoClip,
        trimStartSeconds: Double,
        trimEndSeconds: Double,
        selection: PlateSelection,
        onStartAnalysis: @escaping () -> Void
    ) {
        _model = State(wrappedValue: TrackingPreviewModel(
            clip: clip,
            trimStartSeconds: trimStartSeconds,
            trimEndSeconds: trimEndSeconds,
            selection: selection
        ))
        self.onStartAnalysis = onStartAnalysis
    }

    var body: some View {
        ZStack {
            Theme.Color.background.ignoresSafeArea()

            GeometryReader { geo in
                let rect = model.imageRect(containerSize: geo.size)
                ZStack {
                    VideoLayerView(player: model.player)
                        .frame(width: geo.size.width, height: geo.size.height)

                    if model.phase == .ready {
                        TrajectoryShape(points: model.trajectoryPoints(in: rect))
                            .stroke(Theme.Color.accent.opacity(0.7), lineWidth: 2)

                        if let sample = model.currentSample() {
                            Circle()
                                .fill(.red)
                                .frame(width: 14, height: 14)
                                .position(model.point(for: sample, in: rect))
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }

            VStack {
                statusBar
                Spacer()
                if model.phase == .ready {
                    VStack(spacing: Theme.Space.m) {
                        if model.scaleMismatch {
                            // 非阻擋性（D-029/§1）：追蹤框寬與使用者圈差 > 25%，圈可能沒貼齊槓片。
                            HStack(alignment: .top, spacing: Theme.Space.s) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Theme.Color.warning)
                                    .accessibilityHidden(true)
                                Text("追蹤到的槓片大小與你畫的圓圈相差較多，圓圈可能沒貼齊。返回上一步重新調整圓圈、貼齊槓片外緣會更準。")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Color.textPrimary)
                            }
                            .padding(Theme.Space.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                            .accessibilityElement(children: .combine)
                        }

                        Button("重播") { model.replay() }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.Color.background)
                            .padding(.horizontal, Theme.Space.l)
                            .padding(.vertical, Theme.Space.s)
                            .background(Theme.Color.accent, in: Capsule())

                        PrimaryButton("開始分析", systemImage: "chart.line.uptrend.xyaxis") {
                            model.stop()
                            onStartAnalysis()
                        }
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.bottom, Theme.Space.l)
                }
            }
        }
        .navigationTitle("追蹤驗證")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var statusBar: some View {
        Group {
            switch model.phase {
            case .tracking:
                HStack(spacing: Theme.Space.s) {
                    ProgressView().tint(Theme.Color.accent)
                    Text("分析追蹤中…")
                }
            case .ready:
                Text(summaryText)
            case .failed:
                Text("無法讀取這段影片，請換一段再試。")
                    .foregroundStyle(Theme.Color.danger)
            }
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(Theme.Color.textPrimary)
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
        .background(Theme.Color.surface.opacity(0.85), in: Capsule())
        .padding(.top, Theme.Space.m)
    }

    private var summaryText: String {
        var parts = ["樣本 \(model.samples.count)", "平均信心 \(Int((model.meanConfidence * 100).rounded()))%"]
        if let lost = model.lostAtTime {
            parts.append("在 \(Formatters.timecode(lost)) 附近跟丟")
        } else {
            parts.append("未跟丟")
        }
        return parts.joined(separator: " · ")
    }
}

/// 把一串顯示座標點連成折線（軌跡線）。
private struct TrajectoryShape: Shape {
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
