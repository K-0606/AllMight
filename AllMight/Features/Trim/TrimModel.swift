import Foundation
import Observation
import AVFoundation
import CoreGraphics
import VBTVision

/// 剪輯頁的狀態：片段起訖、縮圖、播放器（見 PRD §3.4）。
///
/// 片段最短 1 秒、最長 60 秒。時間單位為秒，相對影片起點。
@MainActor
@Observable
final class TrimModel {
    static let minClipSeconds = 1.0
    static let maxClipSeconds = 60.0
    static let thumbnailCount = 8

    let clip: VideoClip
    let duration: Double
    private(set) var trimStart: Double
    private(set) var trimEnd: Double
    private(set) var thumbnails: [CGImage] = []

    let player: AVPlayer

    init(clip: VideoClip) {
        self.clip = clip
        self.duration = clip.info.durationSeconds
        self.trimStart = 0
        self.trimEnd = min(clip.info.durationSeconds, Self.maxClipSeconds)
        self.player = AVPlayer(url: clip.url)
    }

    var startFraction: Double { duration > 0 ? trimStart / duration : 0 }
    var endFraction: Double { duration > 0 ? trimEnd / duration : 1 }
    var clipLength: Double { trimEnd - trimStart }

    /// 設定起點把手（以 0–1 的時間軸比例）。維持最短／最長片段限制。
    func updateStart(fraction: Double) {
        let requested = clamp(fraction * duration, 0, duration)
        var newStart = min(requested, trimEnd - Self.minClipSeconds)
        newStart = max(newStart, 0)
        if trimEnd - newStart > Self.maxClipSeconds {
            trimEnd = newStart + Self.maxClipSeconds
        }
        trimStart = newStart
        seek(to: trimStart)
    }

    /// 設定終點把手（以 0–1 的時間軸比例）。維持最短／最長片段限制。
    func updateEnd(fraction: Double) {
        let requested = clamp(fraction * duration, 0, duration)
        var newEnd = max(requested, trimStart + Self.minClipSeconds)
        newEnd = min(newEnd, duration)
        if newEnd - trimStart > Self.maxClipSeconds {
            trimStart = newEnd - Self.maxClipSeconds
        }
        trimEnd = newEnd
        seek(to: trimEnd)
    }

    /// 載入時間軸縮圖（已轉正）。
    func loadThumbnails() async {
        guard duration > 0 else { return }
        let asset = AVURLAsset(url: clip.url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        let count = Self.thumbnailCount
        let times = (0..<count).map { index -> CMTime in
            let fraction = (Double(index) + 0.5) / Double(count)
            return CMTime(seconds: duration * fraction, preferredTimescale: 600)
        }
        var images: [CGImage] = []
        for await result in generator.images(for: times) {
            if case let .success(_, image, _) = result {
                images.append(image)
            }
        }
        thumbnails = images
    }

    private func seek(to seconds: Double) {
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
