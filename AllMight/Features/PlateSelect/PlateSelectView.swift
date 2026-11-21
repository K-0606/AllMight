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

                    // 偵測到的槓片框；被選取的高亮（Stage 1 標記 + Stage 2 選取，見 DECISIONS D-033）。
                    ForEach(Array(model.detectedPlates.enumerated()), id: \.offset) { _, plate in
                        DetectionBox(
                            rect: model.boxRect(for: plate),
                            confidence: plate.confidence,
                            isSelected: plate == model.selectedPlate
                        )
                    }

                    if model.isCirclePlaced {
                        PlateCircleOverlay(center: model.circleCenter, diameter: model.circleDiameter)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(pickTapGesture)
                .simultaneousGesture(moveDragGesture)
                .simultaneousGesture(magnifyGesture)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("槓片對齊圓圈")
                .accessibilityValue(accessibilityValueText)
                .accessibilityHint("點選偵測到的槓片，或點兩下把圓圈放在畫面中央，再用調整手勢改變大小")
                .accessibilityActions {
                    ForEach(Array(model.detectedPlates.enumerated()), id: \.offset) { index, plate in
                        Button("選擇第 \(index + 1) 個槓片") { model.selectPlate(plate) }
                    }
                    Button("把圓圈放在中央") { model.placeCircleAtImageCenter() }
                }
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

            VStack(spacing: Theme.Space.xs) {
                Text(model.isCirclePlaced ? "已選取，可拖曳／縮放微調，或點其他框改選" : "點一下偵測到的槓片來選取")
                    .font(.footnote)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .padding(.horizontal, Theme.Space.m)
                    .padding(.vertical, Theme.Space.s)
                    .background(Theme.Color.surface.opacity(0.85), in: Capsule())
                    .padding(.top, Theme.Space.m)

                // Stage 1 偵測狀態（診斷用，見 DECISIONS D-033）。
                Group {
                    if model.isDetecting {
                        Text("偵測槓片中…")
                    } else if let err = model.detectionErrorText {
                        Text(verbatim: "偵測失敗：\(err)")
                    } else {
                        Text("偵測到 \(model.detectedPlates.count) 個槓片")
                    }
                }
                .font(.caption2.monospacedDigit())
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Color.textSecondary)
                .padding(.horizontal, Theme.Space.s)
                .padding(.vertical, Theme.Space.xs)
                .background(Theme.Color.surface.opacity(0.7), in: Capsule())

                if model.isCirclePlaced {
                    // D-029：圓圈兼作比例尺，貼齊外緣越準；包進槓桿/背景會讓追蹤抖、校正偏。
                    Text("圓圈剛好框住槓片外緣，速度與幅度才會準；不要包含槓桿或背景。")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .padding(.horizontal, Theme.Space.m)
                        .padding(.vertical, Theme.Space.xs)
                        .background(Theme.Color.surface.opacity(0.7), in: Capsule())
                }

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
        .task { await model.detectPlates() }
    }

    private var accessibilityValueText: String {
        model.isCirclePlaced ? "圓圈直徑約為畫面寬的 \(model.diameterPercentOfWidth())%" : "尚未放置圓圈"
    }

    /// 點一下：選偵測框 / 或在空白處手動放圈（同步命中測試，見 DECISIONS D-033）。
    private var pickTapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in model.handleTap(at: value.location) }
    }

    /// 拖曳（位移 > 10pt 才算，與點選區分）：移動已放置的圈做微調。
    private var moveDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard model.isCirclePlaced else { return }
                model.moveCircle(to: value.location)
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

/// 一個偵測到的槓片框 + 左上角可信度標籤；被選取時加粗並填淡色（純標記，不可點擊；見 DECISIONS D-033）。
private struct DetectionBox: View {
    let rect: CGRect
    let confidence: Double
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Rectangle()
                    .fill(Theme.Color.accent.opacity(0.18))
                    .frame(width: rect.width, height: rect.height)
            }
            Rectangle()
                .strokeBorder(Theme.Color.accent, lineWidth: isSelected ? 4 : 2)
                .frame(width: rect.width, height: rect.height)
                .overlay(alignment: .topLeading) {
                    Text(confidence, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(Theme.Color.background)
                        .padding(.horizontal, 3)
                        .background(Theme.Color.accent)
                }
        }
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
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
