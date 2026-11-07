import SwiftUI
import VBTCore
import VBTVision

/// 點選槓片頁：顯示片段起點幀，使用者點一下槓片出現圓圈，再拖曳/縮放對齊外緣，換算成 `PlateSelection`（見 PRD §3.5）。
///
/// 「鎖定並追蹤」把圓圈交給追蹤（追蹤與分析在 M4／M5 接上）；「重新選擇片段」回到剪輯頁。
struct PlateSelectView: View {
    @State private var model: PlateSelectModel
    /// 使用者鎖定圓圈後回傳換算好的 `PlateSelection`。
    var onLocked: (PlateSelection) -> Void
    /// 回到剪輯頁重新選片段。
    var onReselect: () -> Void

    @State private var lastMagnification = 1.0

    init(
        clip: VideoClip,
        trimStartSeconds: Double,
        trimEndSeconds: Double,
        onLocked: @escaping (PlateSelection) -> Void,
        onReselect: @escaping () -> Void
    ) {
        _model = State(wrappedValue: PlateSelectModel(
            clip: clip,
            trimStartSeconds: trimStartSeconds,
            trimEndSeconds: trimEndSeconds
        ))
        self.onLocked = onLocked
        self.onReselect = onReselect
    }

    var body: some View {
        ZStack {
            Theme.Color.background.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    if let frame = model.startFrame {
                        Image(decorative: frame, scale: 1, orientation: .up)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        ProgressView()
                            .tint(Theme.Color.accent)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }

                    if model.isCirclePlaced {
                        PlateCircleOverlay(center: model.circleCenter, diameter: model.circleDiameter)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(placeOrMoveGesture)
                .simultaneousGesture(magnifyGesture)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("槓片對齊圓圈")
                .accessibilityValue(accessibilityValueText)
                .accessibilityHint("點兩下把圓圈放在畫面中央，再用調整手勢改變大小")
                .accessibilityAction(named: "把圓圈放在中央") { model.placeCircleAtImageCenter() }
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: model.adjustDiameter(enlarge: true)
                    case .decrement: model.adjustDiameter(enlarge: false)
                    @unknown default: break
                    }
                }
                .onAppear { model.updateContainer(size: geo.size) }
                .onChange(of: geo.size) { _, size in model.updateContainer(size: size) }
            }

            VStack {
                Text(model.isCirclePlaced ? "調整圓圈貼齊槓片外緣" : "點一下你要追蹤的槓片")
                    .font(.footnote)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .padding(.horizontal, Theme.Space.m)
                    .padding(.vertical, Theme.Space.s)
                    .background(Theme.Color.surface.opacity(0.85), in: Capsule())
                    .padding(.top, Theme.Space.m)
                Spacer()
            }
        }
        .navigationTitle("點選槓片")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("重新選擇片段") { onReselect() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("鎖定並追蹤") {
                    onLocked(model.currentSelection())
                }
                .disabled(model.startFrame == nil || !model.isCirclePlaced)
            }
        }
        .task { await model.loadStartFrame() }
    }

    private var accessibilityValueText: String {
        model.isCirclePlaced ? "圓圈直徑約為畫面寬的 \(model.diameterPercentOfWidth())%" : "尚未放置圓圈"
    }

    /// 點一下放置圓圈、拖曳移動圓心（`minimumDistance: 0` 讓單點也能觸發）。
    private var placeOrMoveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if model.isCirclePlaced {
                    model.moveCircle(to: value.location)
                } else {
                    model.placeCircle(at: value.location)
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard model.isCirclePlaced else { return }
                model.scaleCircle(by: value.magnification / lastMagnification)
                lastMagnification = value.magnification
            }
            .onEnded { _ in lastMagnification = 1.0 }
    }
}

#Preview {
    NavigationStack {
        PlateSelectView(
            clip: VideoClip(
                url: URL(fileURLWithPath: "/dev/null"),
                info: VideoInfo(
                    durationSeconds: 10,
                    geometry: VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60),
                    orientation: .right,
                    isLowFrameRate: false,
                    codec: "hvc1",
                    isHDR: true
                )
            ),
            trimStartSeconds: 0,
            trimEndSeconds: 5,
            onLocked: { _ in },
            onReselect: { }
        )
        .preferredColorScheme(.dark)
    }
}
