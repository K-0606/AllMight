import SwiftUI
import PhotosUI
import os
import VBTCore
import VBTVision

/// 影片設定頁：選動作、重量（kg）、槓片直徑，然後用 PhotosPicker 選影片。
///
/// 選到影片後檢查，通過才搬進 Application Support/Videos/ 並呼叫 `onReady` 進入剪輯。
struct VideoSetupView: View {
    @Bindable var model: VideoSetupModel
    /// 影片通過檢查後回傳可剪輯的片段。
    var onReady: (VideoClip) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: LocalizedStringKey?
    @FocusState private var loadFieldFocused: Bool

    private let fileStore = FileStore()
    private static let logger = Logger(subsystem: "com.kun0606.AllMight", category: "VideoImport")

    var body: some View {
        ZStack {
            Theme.Color.background.ignoresSafeArea()

            Form {
                exerciseSection
                loadSection
                diameterSection
                pickerSection
            }
            .scrollContentBackground(.hidden)
            .disabled(isLoading)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { loadFieldFocused = false }
                }
            }
            .onChange(of: loadFieldFocused) { _, focused in
                if !focused {
                    model.loadKg = VideoSetupModel.clampLoad(model.loadKg)
                }
            }

            if isLoading {
                loadingOverlay
            }
        }
        .navigationTitle("影片設定")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { _, newValue in
            guard let newValue else { return }
            Task { await handlePicked(newValue) }
        }
    }

    // MARK: - Sections

    private var exerciseSection: some View {
        Section {
            Picker("動作", selection: $model.exercise) {
                ForEach(Exercise.allCases, id: \.self) { exercise in
                    Text(exercise.displayName).tag(exercise)
                }
            }
        }
        .listRowBackground(Theme.Color.surface)
    }

    private var loadSection: some View {
        Section {
            HStack(spacing: Theme.Space.m) {
                // 整個「重量 … kg」區域都可點擊叫出鍵盤，不用只點數字。
                HStack(spacing: Theme.Space.s) {
                    Text("重量")
                    Spacer(minLength: Theme.Space.m)
                    TextField("重量", value: $model.loadKg, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .focused($loadFieldFocused)
                        .fixedSize()
                    Text("kg")
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { loadFieldFocused = true }

                Stepper(
                    "重量",
                    value: $model.loadKg,
                    in: VideoSetupModel.minLoadKg...VideoSetupModel.maxLoadKg,
                    step: VideoSetupModel.loadStepKg
                )
                .labelsHidden()
                .fixedSize()
            }
        }
        .listRowBackground(Theme.Color.surface)
    }

    private var diameterSection: some View {
        Section {
            Picker("槓片直徑", selection: $model.useStandardDiameter) {
                Text("45 cm · 標準").tag(true)
                Text("自訂").tag(false)
            }
            if !model.useStandardDiameter {
                Stepper(
                    value: $model.customDiameterCm,
                    in: VideoSetupModel.minDiameterCm...VideoSetupModel.maxDiameterCm,
                    step: 1
                ) {
                    LabeledContent("自訂直徑") {
                        Text(Formatters.diameterCm(model.customDiameterCm))
                            .monospacedDigit()
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
            }
        } footer: {
            Text("槓片直徑用來把畫面的像素換算成實際距離。")
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .listRowBackground(Theme.Color.surface)
    }

    private var pickerSection: some View {
        Section {
            // .current：盡量用原始編碼、避免把 HDR/Dolby Vision 轉碼成 SDR（見 DECISIONS D-018）。
            PhotosPicker(selection: $photoItem, matching: .videos, preferredItemEncoding: .current) {
                SelectVideoButtonLabel()
            }
            .listRowInsets(EdgeInsets(top: Theme.Space.s, leading: Theme.Space.l, bottom: Theme.Space.s, trailing: Theme.Space.l))
            .listRowBackground(Color.clear)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.Color.danger)
                    .listRowBackground(Color.clear)
            }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: Theme.Space.m) {
                ProgressView()
                    .tint(Theme.Color.accent)
                Text("正在載入影片…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Color.textPrimary)
            }
            .padding(Theme.Space.xl)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - 選片處理

    private func handlePicked(_ item: PhotosPickerItem) async {
        errorMessage = nil
        isLoading = true
        defer {
            isLoading = false
            photoItem = nil
        }
        do {
            let startedAt = Date()
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                errorMessage = Self.message(for: .videoUnreadable)
                return
            }
            let afterTransfer = Date()
            let tempURL = movie.url
            do {
                // 先檢查，通過才把暫存檔搬進 Videos：避免留下不合規的檔案，也省掉一次整檔複製。
                let info = try await VideoInspector.inspect(url: tempURL)
                let afterInspect = Date()
                let fileName = UUID().uuidString + "." + (tempURL.pathExtension.isEmpty ? "mov" : tempURL.pathExtension)
                let storedURL = try fileStore.moveIn(.videos, sourceURL: tempURL, fileName: fileName)
                let afterStore = Date()
                Self.logger.info("影片載入耗時（秒）transfer=\(afterTransfer.timeIntervalSince(startedAt), privacy: .public) inspect=\(afterInspect.timeIntervalSince(afterTransfer), privacy: .public) store=\(afterStore.timeIntervalSince(afterInspect), privacy: .public)")
                Self.logger.info("影片資訊 codec=\(info.codec, privacy: .public) hdr=\(info.isHDR, privacy: .public) 解析度=\(info.geometry.widthPx, privacy: .public)x\(info.geometry.heightPx, privacy: .public) fps=\(info.geometry.nominalFPS, privacy: .public) 方向=\(String(describing: info.orientation), privacy: .public) 長度秒=\(info.durationSeconds, privacy: .public) 低影格率=\(info.isLowFrameRate, privacy: .public)")
                model.persist()
                onReady(VideoClip(url: storedURL, info: info))
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                throw error
            }
        } catch let error as AnalysisError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = Self.message(for: .videoUnreadable)
        }
    }

    /// 把匯入階段的錯誤對應成 PRD §3.3 的使用者文字。
    private static func message(for error: AnalysisError) -> LocalizedStringKey {
        switch error {
        case .unsupportedSlowMotion:
            "這是慢動作影片。請先在照片 App 中把慢動作改成一般速度，或匯出後再選。"
        case .frameRateTooLow:
            "影片的影格率太低。請用每秒至少 24 格（建議 60fps）重新錄影。"
        case .videoTooShort:
            "影片太短。請選擇長度至少 1 秒的影片。"
        case .videoTooLong:
            "影片太長。請選擇 3 分鐘以內的影片。"
        case .videoUnreadable, .trackingLost, .noRepsDetected, .cancelled:
            "無法讀取這段影片，請換一段再試。"
        }
    }
}

/// 「選擇影片」主按鈕外觀。獨立成型別，避免在 PhotosPicker 的 Sendable label 閉包裡
/// 直接參照 MainActor 隔離的 Theme token。
private struct SelectVideoButtonLabel: View {
    var body: some View {
        Text("選擇影片")
            .font(.headline)
            .foregroundStyle(Theme.Color.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.m)
            .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
    }
}

#Preview {
    NavigationStack {
        VideoSetupView(model: VideoSetupModel()) { _ in }
            .preferredColorScheme(.dark)
    }
}
