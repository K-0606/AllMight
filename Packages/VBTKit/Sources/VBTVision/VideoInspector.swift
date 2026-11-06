import Foundation
import AVFoundation
import CoreMedia
import VBTCore

/// 影片匯入的檢查門檻（見 docs/PRD.md §3.3、docs/DECISIONS.md D-013）。
///
/// 時間單位為秒，影格率為 fps。數值集中於此，不寫死在判斷式裡（見 .claude/rules/swift-style.md）。
public struct VideoImportLimits: Sendable {
    /// 最短可接受長度（秒）。
    public var minDurationSeconds: Double
    /// 最長可接受長度（秒）。
    public var maxDurationSeconds: Double
    /// 可分析的最低影格率；低於此直接阻擋。
    public var minFrameRate: Double
    /// 建議影格率；低於此可繼續但提示使用者。
    public var recommendedFrameRate: Double
    /// 視為慢動作的影格率上限；高於此直接阻擋。
    public var slowMotionFrameRate: Double
    /// 時間變速偵測容差：片段來源/目標時長比例偏離 1:1 超過此值即視為慢動作。
    /// 真實慢動作比例（0.5、0.25）遠大於此；此值待真實慢動作影片實測後再定。
    public var timeRemapTolerance: Double

    public init(
        minDurationSeconds: Double,
        maxDurationSeconds: Double,
        minFrameRate: Double,
        recommendedFrameRate: Double,
        slowMotionFrameRate: Double,
        timeRemapTolerance: Double
    ) {
        self.minDurationSeconds = minDurationSeconds
        self.maxDurationSeconds = maxDurationSeconds
        self.minFrameRate = minFrameRate
        self.recommendedFrameRate = recommendedFrameRate
        self.slowMotionFrameRate = slowMotionFrameRate
        self.timeRemapTolerance = timeRemapTolerance
    }

    /// PRD §3.3 的預設門檻：1 秒–3 分鐘、最低 24 fps、建議 50 fps、>120 fps 視為慢動作。
    public static let standard = VideoImportLimits(
        minDurationSeconds: 1,
        maxDurationSeconds: 180,
        minFrameRate: 24,
        recommendedFrameRate: 50,
        slowMotionFrameRate: 120,
        timeRemapTolerance: 0.01
    )
}

/// 影片檢查結果：長度、轉正尺寸與影格率、方向，以及是否低於建議影格率。
public struct VideoInfo: Sendable, Equatable {
    /// 影片總長度（秒）。
    public var durationSeconds: Double
    /// 轉正後的尺寸與標稱影格率。
    public var geometry: VideoGeometry
    /// 顯示方向。
    public var orientation: VideoOrientation
    /// 影格率低於建議值（可繼續，但應提示使用者用更高 fps 錄影）。
    public var isLowFrameRate: Bool
    /// 影片編碼的 FourCC 字串，例如 "hvc1"（HEVC/H.265）、"avc1"（H.264）；讀不到時為 "unknown"。
    public var codec: String
    /// 是否為 HDR 影片（含 HDR 色彩特性，如 iPhone 的 Dolby Vision）。供診斷與未來匯出 tone-map 判斷用。
    public var isHDR: Bool

    public init(
        durationSeconds: Double,
        geometry: VideoGeometry,
        orientation: VideoOrientation,
        isLowFrameRate: Bool,
        codec: String,
        isHDR: Bool
    ) {
        self.durationSeconds = durationSeconds
        self.geometry = geometry
        self.orientation = orientation
        self.isLowFrameRate = isLowFrameRate
        self.codec = codec
        self.isHDR = isHDR
    }
}

/// 讀取影片的時長、影格率、轉正尺寸、方向，並做匯入前檢查（見 skill video-pipeline §1）。
public enum VideoInspector {
    /// 檢查影片並回傳 `VideoInfo`；不合規時丟出對應的 `AnalysisError`。
    public static func inspect(url: URL, limits: VideoImportLimits = .standard) async throws -> VideoInfo {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw AnalysisError.videoUnreadable
        }
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)
        let segments = try await track.load(.segments)
        let formatDescriptions = try await track.load(.formatDescriptions)
        let mediaCharacteristics = try await track.load(.mediaCharacteristics)

        let fps = Double(nominalFrameRate)
        let durationSeconds = duration.seconds
        let timeRemapped = hasTimeRemappedSegments(segments, tolerance: limits.timeRemapTolerance)

        if let error = validate(
            durationSeconds: durationSeconds,
            fps: fps,
            hasTimeRemappedSegments: timeRemapped,
            limits: limits
        ) {
            throw error
        }

        // 轉正尺寸：套用 preferredTransform 後取絕對值寬高（見 skill video-pipeline §1）。
        let orientedRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let geometry = VideoGeometry(
            widthPx: Int(abs(orientedRect.width).rounded()),
            heightPx: Int(abs(orientedRect.height).rounded()),
            nominalFPS: fps
        )
        return VideoInfo(
            durationSeconds: durationSeconds,
            geometry: geometry,
            orientation: VideoOrientation.from(transform: transform),
            isLowFrameRate: fps < limits.recommendedFrameRate,
            codec: codecString(from: formatDescriptions),
            isHDR: mediaCharacteristics.contains(.containsHDRVideo)
        )
    }

    /// 取第一個 format description 的視訊編碼 FourCC（如 "hvc1"、"avc1"）；沒有時回傳 "unknown"。
    static func codecString(from descriptions: [CMFormatDescription]) -> String {
        guard let first = descriptions.first else { return "unknown" }
        return fourCCString(CMFormatDescriptionGetMediaSubType(first))
    }

    /// 把 FourCharCode 轉成可讀字串（4 個 ASCII 位元組）。
    static func fourCCString(_ code: FourCharCode) -> String {
        let bytes: [CChar] = [
            CChar(truncatingIfNeeded: Int32((code >> 24) & 0xff)),
            CChar(truncatingIfNeeded: Int32((code >> 16) & 0xff)),
            CChar(truncatingIfNeeded: Int32((code >> 8) & 0xff)),
            CChar(truncatingIfNeeded: Int32(code & 0xff)),
            0,
        ]
        return String(cString: bytes).trimmingCharacters(in: .whitespaces)
    }

    /// 匯入前的純判斷：回傳應阻擋的錯誤，或 nil 表示可繼續。
    ///
    /// 檢查順序：慢動作 → 影格率過低 → 太短 → 太長（長度在影格率之後，
    /// 讓「請用更高 fps」這類更根本的問題優先顯示）。
    static func validate(
        durationSeconds: Double,
        fps: Double,
        hasTimeRemappedSegments: Bool,
        limits: VideoImportLimits
    ) -> AnalysisError? {
        // 時長／影格率非有限值（損毀檔、不定長度串流）視為無法讀取。
        guard durationSeconds.isFinite, durationSeconds >= 0, fps.isFinite, fps > 0 else {
            return .videoUnreadable
        }
        if fps > limits.slowMotionFrameRate || hasTimeRemappedSegments {
            return .unsupportedSlowMotion
        }
        if fps < limits.minFrameRate {
            return .frameRateTooLow(fps)
        }
        if durationSeconds < limits.minDurationSeconds {
            return .videoTooShort(seconds: durationSeconds)
        }
        if durationSeconds > limits.maxDurationSeconds {
            return .videoTooLong(seconds: durationSeconds)
        }
        return nil
    }

    /// 是否有時間變速的片段（慢動作匯出常見）：來源與目標時長比例偏離 1:1 超過容差。
    static func hasTimeRemappedSegments(_ segments: [AVAssetTrackSegment], tolerance: Double) -> Bool {
        for segment in segments where !segment.isEmpty {
            let mapping = segment.timeMapping
            let source = mapping.source.duration
            let target = mapping.target.duration
            guard source.isValid, target.isValid, target.seconds > 0, source.seconds > 0 else { continue }
            if abs(source.seconds / target.seconds - 1.0) > tolerance {
                return true
            }
        }
        return false
    }
}
