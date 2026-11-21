import Foundation
import Vision
import CoreML
import CoreVideo
import CoreImage
import CoreGraphics
import os
import VBTCore

/// 用 Core ML（YOLOv8n→Core ML）在起點幀偵測槓片框（見 docs/ALGORITHMS.md §9、DECISIONS D-033）。
///
/// 只產生建議框，不碰追蹤與校正的數值路徑；偵測不到任何框回空陣列，呼叫端退回純手動。
/// 模型隨 VBTVision 套件打包（`Resources/BarbellDetector.mlpackage`），執行時編譯一次並快取編譯後 URL。
/// Vision / Core ML 物件只在本 actor 內建立與使用，不跨 actor 傳遞；對外只回傳 `Sendable` 的 `[DetectedPlate]`。
public actor PlateDetector {
    private static let logger = Logger(subsystem: "com.kun0606.AllMight", category: "Detection")

    /// 抓單幀用的讀取視窗長度（秒）：夠長以涵蓋至少一幀，VFR 也安全。
    private static let readWindowSeconds = 1.0

    /// 把 `FrameReader` 的 YUV/HDR 緩衝 render 成乾淨 RGB CGImage 用（見下方 detect 的格式修正）。
    /// `CIContext` 建立較貴，存成 actor 屬性只建一次；actor 隔離，無 Sendable 問題。
    private let ciContext = CIContext()

    public init() {}

    /// 在影片 `atSeconds` 處抓一幀，用 Core ML 偵測槓片，回傳 `[DetectedPlate]`（信心高到低）。
    ///
    /// `atSeconds` 用剪輯片段起點（＝使用者在點選槓片頁看到的那一幀）。座標為 Vision 正規化（原點左下、轉正空間），
    /// 與 `PlateSelection`/追蹤一致。讀不到影像軌道丟 `AnalysisError.videoUnreadable`；視窗內無幀回空陣列。
    public func detect(url: URL, atSeconds: Double) async throws -> [DetectedPlate] {
        let start = max(0, atSeconds)
        let reader = try await FrameReader(
            url: url, trimStartSeconds: start, trimEndSeconds: start + Self.readWindowSeconds
        )
        let geometry = reader.geometry
        defer { reader.cancel() }
        guard let frame = try reader.next() else { return [] }

        // 把來源 YUV/HDR 緩衝 render 成乾淨 RGB CGImage 再交給 Vision。
        // FrameReader 的 8-bit 420 biplanar（HDR 來源降位）直接餵 Core ML 影像輸入，裝置/模擬器上會丟
        // 「verify_image_parameters: invalid image bits/pixel」而偵測失敗；經 CoreImage 轉 CGImage 可穩定（見 DECISIONS D-033）。
        let ciImage = CIImage(cvPixelBuffer: frame.pixelBuffer)
        // 明確 render 成 **8-bit sRGB**：HDR/10-bit HLG 來源若用預設可能產生 16-bit/廣色域 CGImage，
        // Core ML 影像輸入只吃 8-bit → 丟「verify_image_parameters: invalid image bits/pixel」。
        // 強制 `.RGBA8` + sRGB 做 tone-map 降位，sim/device/HDR 都穩定（見 DECISIONS D-033、D-019）。
        let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let cgImage = ciContext.createCGImage(
            ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: outputColorSpace
        ) else {
            throw PlateDetectorError.frameConversionFailed
        }

        let vnModel = try await Self.visionModel()
        let request = VNCoreMLRequest(model: vnModel)
        // YOLO 以等比例 letterbox 預處理訓練；用 .scaleFit（等比例縮放+留白）對齊，框才會準。
        request.imageCropAndScaleOption = .scaleFit

        // 保留 frame.orientation：CGImage 是來源方向的像素，Vision 以此轉正，框落在轉正正規化空間。
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: frame.orientation)
        try handler.perform([request])

        let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []
        // boundingBox：Vision 正規化、原點左下、已是轉正影像座標（因 handler 帶了 orientation）。
        let plates = observations.map { obs in
            DetectedPlate(
                centerX: obs.boundingBox.midX,
                centerY: obs.boundingBox.midY,
                width: obs.boundingBox.width,
                height: obs.boundingBox.height,
                confidence: Double(obs.confidence)
            )
        }.sorted { $0.confidence > $1.confidence }

        Self.logger.info("偵測：槓片框=\(plates.count, privacy: .public) 最高信心=\(plates.first?.confidence ?? 0, privacy: .public)")
        return plates
    }

    // MARK: - 模型載入（編譯一次、快取編譯後 URL）

    /// 快取「編譯後模型 URL」（`URL` 為 `Sendable`，可跨 actor；避免每次重編譯這個慢步驟）。
    private static let compiledURLCache = CompiledModelCache()

    /// 建立本次推論用的 `VNCoreMLModel`（從快取的編譯後模型載入；物件留在呼叫的 actor 內，不跨界）。
    private static func visionModel() async throws -> VNCoreMLModel {
        let compiledURL = try await compiledURLCache.url()
        let mlModel = try MLModel(contentsOf: compiledURL)
        return try VNCoreMLModel(for: mlModel)
    }
}

/// 偵測模型載入錯誤。
enum PlateDetectorError: Error {
    /// 套件資源裡找不到模型檔。
    case modelResourceMissing
    /// 來源影格無法 render 成 CGImage。
    case frameConversionFailed
}

/// 解析出「可直接載入的模型 URL」並快取一次。
///
/// 裝置（Xcode App build）資源包裡是已編譯的 `.mlmodelc` → 直接用；macOS `swift test`（SPM `.copy`）
/// 是原始 `.mlpackage` → 執行時編譯。兩種都回傳 `MLModel(contentsOf:)` 可直接載入的 URL。
/// 快取「工作」而非 URL：同時首呼也只做一次（共用同一 `Task`）；失敗不永久快取、容許重試。
private actor CompiledModelCache {
    private var task: Task<URL, Error>?

    func url() async throws -> URL {
        if let task { return try await task.value }
        let newTask = Task { () throws -> URL in
            // Xcode 的 App build 會把 .mlpackage 編成 .mlmodelc 放進資源包 → 直接載入（裝置路徑）。
            if let compiled = Bundle.module.url(forResource: "BarbellDetector", withExtension: "mlmodelc") {
                return compiled
            }
            // SPM `.copy`（macOS `swift test`）保留原始 .mlpackage → 執行時編譯成 .mlmodelc。
            guard let packageURL = Bundle.module.url(forResource: "BarbellDetector", withExtension: "mlpackage") else {
                throw PlateDetectorError.modelResourceMissing
            }
            return try await MLModel.compileModel(at: packageURL)
        }
        task = newTask
        do {
            return try await newTask.value
        } catch {
            task = nil // 失敗不要永久快取
            throw error
        }
    }
}
