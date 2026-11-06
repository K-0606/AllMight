import SwiftUI
import PhotosUI
import VBTCore
import VBTVision

/// 影片設定頁：選動作、重量（kg）、槓片直徑，然後用 PhotosPicker 選影片。
///
/// 選到影片後複製到 Application Support/Videos/ 並檢查；通過才呼叫 `onReady` 進入剪輯。
struct VideoSetupView: View {
    @Bindable var model: VideoSetupModel
    /// 影片通過檢查後回傳可剪輯的片段。
    var onReady: (VideoClip) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: LocalizedStringKey?

    private let fileStore = FileStore()

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
            Stepper(
                value: $model.loadKg,
                in: VideoSetupModel.minLoadKg...VideoSetupModel.maxLoadKg,
                step: VideoSetupModel.loadStepKg
            ) {
                LabeledContent("重量") {
                    Text(Formatters.weightKg(model.loadKg))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Color.textSecondary)
                }
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
            PhotosPicker(selection: $photoItem, matching: .videos) {
                Text("選擇影片")
                    .font(.headline)
                    .foregroundStyle(Theme.Color.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.m)
                    .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
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
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                errorMessage = Self.message(for: .videoUnreadable)
                return
            }
            let tempURL = movie.url
            defer { try? FileManager.default.removeItem(at: tempURL) }

            // 先檢查，通過才複製進 Videos，避免留下不合規的檔案。
            let info = try await VideoInspector.inspect(url: tempURL)
            let fileName = UUID().uuidString + "." + (tempURL.pathExtension.isEmpty ? "mov" : tempURL.pathExtension)
            let storedURL = try fileStore.store(.videos, sourceURL: tempURL, fileName: fileName)

            model.persist()
            onReady(VideoClip(url: storedURL, info: info))
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

#Preview {
    NavigationStack {
        VideoSetupView(model: VideoSetupModel()) { _ in }
            .preferredColorScheme(.dark)
    }
}
