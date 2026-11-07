import SwiftUI
import AVKit
import VBTVision

/// 剪出分析片段：上方播放器，下方縮圖時間軸與起訖把手（見 PRD §3.4）。
///
/// 「完成」將在 M2 帶著片段進入「點選槓片」。
struct TrimView: View {
    @State private var model: TrimModel
    /// 「完成」後帶著片段起訖進入「點選槓片」。
    var onContinue: (_ trimStartSeconds: Double, _ trimEndSeconds: Double) -> Void

    init(
        clip: VideoClip,
        onContinue: @escaping (_ trimStartSeconds: Double, _ trimEndSeconds: Double) -> Void
    ) {
        _model = State(wrappedValue: TrimModel(clip: clip))
        self.onContinue = onContinue
    }

    var body: some View {
        ZStack {
            Theme.Color.background.ignoresSafeArea()

            VStack(spacing: Theme.Space.l) {
                VideoPlayer(player: model.player)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

                if model.clip.info.isLowFrameRate {
                    Text("建議用 60fps 錄影，速度會更準")
                        .font(.footnote)
                        .foregroundStyle(Theme.Color.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Text(Formatters.timecode(model.trimStart))
                    Spacer()
                    Text("長度 \(Formatters.timecode(model.clipLength))")
                    Spacer()
                    Text(Formatters.timecode(model.trimEnd))
                }
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.Color.textSecondary)

                TimelineStrip(
                    thumbnails: model.thumbnails,
                    startFraction: model.startFraction,
                    endFraction: model.endFraction,
                    duration: model.duration,
                    adjustStep: model.duration > 0 ? 1.0 / model.duration : 0.05,
                    onChangeStart: { model.updateStart(fraction: $0) },
                    onChangeEnd: { model.updateEnd(fraction: $0) }
                )
                .frame(height: 64)

                Spacer()
            }
            .padding(Theme.Space.l)
        }
        .navigationTitle("剪出分析片段")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    onContinue(model.trimStart, model.trimEnd)
                }
            }
        }
        .task { await model.loadThumbnails() }
    }
}
