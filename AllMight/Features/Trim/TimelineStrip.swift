import SwiftUI
import CoreGraphics

/// 剪輯時間軸：一排縮圖、選取範圍外變暗、左右兩個可拖曳把手（見 PRD §3.4）。
///
/// 位置以 0–1 的比例表示；把手移動時回報新的比例給上層的 `TrimModel`。
struct TimelineStrip: View {
    let thumbnails: [CGImage]
    let startFraction: Double
    let endFraction: Double
    /// VoiceOver 微調用的步進（秒÷總長換成比例）。
    let adjustStep: Double
    let onChangeStart: (Double) -> Void
    let onChangeEnd: (Double) -> Void

    private let handleWidth: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let startX = width * startFraction
            let endX = width * endFraction

            ZStack(alignment: .leading) {
                thumbnailRow(width: width)

                Color.black.opacity(0.55)
                    .frame(width: max(0, startX))
                Color.black.opacity(0.55)
                    .frame(width: max(0, width - endX))
                    .offset(x: endX)

                RoundedRectangle(cornerRadius: Theme.Radius.button)
                    .stroke(Theme.Color.accent, lineWidth: 2)
                    .frame(width: max(0, endX - startX))
                    .offset(x: startX)

                handle(label: "片段起點", valueSeconds: startFraction)
                    .offset(x: startX - handleWidth / 2)
                    .gesture(dragGesture(width: width, isStart: true))
                    .accessibilityAdjustableAction { direction in
                        adjust(isStart: true, direction: direction)
                    }

                handle(label: "片段終點", valueSeconds: endFraction)
                    .offset(x: endX - handleWidth / 2)
                    .gesture(dragGesture(width: width, isStart: false))
                    .accessibilityAdjustableAction { direction in
                        adjust(isStart: false, direction: direction)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
        }
    }

    private func thumbnailRow(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            if thumbnails.isEmpty {
                Theme.Color.surfaceHi
            } else {
                ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                }
            }
        }
        .frame(width: width)
    }

    private func handle(label: LocalizedStringKey, valueSeconds: Double) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Theme.Color.accent)
            .frame(width: handleWidth)
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.Color.background)
                    .frame(width: 2, height: 16)
            )
            .accessibilityElement()
            .accessibilityLabel(label)
    }

    private func dragGesture(width: CGFloat, isStart: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let fraction = min(max(value.location.x / width, 0), 1)
                if isStart { onChangeStart(fraction) } else { onChangeEnd(fraction) }
            }
    }

    private func adjust(isStart: Bool, direction: AccessibilityAdjustmentDirection) {
        let delta = direction == .increment ? adjustStep : -adjustStep
        if isStart {
            onChangeStart(min(max(startFraction + delta, 0), 1))
        } else {
            onChangeEnd(min(max(endFraction + delta, 0), 1))
        }
    }
}
