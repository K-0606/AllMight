import Foundation
import Observation
import AVFoundation
import CoreGraphics
import VBTCore
import VBTVision

/// 追蹤驗證頁的狀態：跑 `TrackingRunner` 取得軌跡，並隨影片重播把追蹤點疊在槓片上（目視確認追蹤是否正確）。
///
/// 影片以剪好的片段重播（`trimStart…trimEnd`）並自動循環；追蹤點用 Vision 正規化座標換算成顯示座標。
@MainActor
@Observable
final class TrackingPreviewModel {
    enum Phase: Equatable { case tracking, ready, failed }

    let geometry: VideoGeometry
    let trimStartSeconds: Double
    let trimEndSeconds: Double
    let player: AVPlayer

    private let videoURL: URL
    private let selection: PlateSelection

    private(set) var phase: Phase = .tracking
    private(set) var samples: [TrackSample] = []
    private(set) var lostAtTime: Double?
    private(set) var meanConfidence = 0.0
    private(set) var frameCount = 0
    /// 目前播放時間（秒，相對片段起點）。
    private(set) var currentTimeInClip = 0.0

    private var timeObserver: Any?

    init(clip: VideoClip, trimStartSeconds: Double, trimEndSeconds: Double, selection: PlateSelection) {
        self.videoURL = clip.url
        self.geometry = clip.info.geometry
        self.trimStartSeconds = trimStartSeconds
        self.trimEndSeconds = trimEndSeconds
        self.selection = selection
        self.player = AVPlayer(url: clip.url)
    }

    /// 跑追蹤；完成後開始重播並疊圖。
    func start() async {
        do {
            let run = try await TrackingRunner().run(
                url: videoURL,
                trimStartSeconds: trimStartSeconds,
                trimEndSeconds: trimEndSeconds,
                selection: selection
            )
            samples = run.samples
            lostAtTime = run.lostAtTime
            meanConfidence = run.meanConfidence
            frameCount = run.frameCount
            phase = .ready
            startPlayback()
        } catch {
            phase = .failed
        }
    }

    /// 停止重播並移除觀察者（離開畫面時呼叫）。
    func stop() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player.pause()
    }

    /// 從片段起點重新播放。
    func replay() {
        seekToStart()
        player.play()
    }

    private func startPlayback() {
        player.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimEndSeconds, preferredTimescale: 600)
        seekToStart()
        let interval = CMTime(seconds: 1.0 / 30, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // queue 為 .main，故可安全斷定在 MainActor 上。
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTimeInClip = max(0, time.seconds - self.trimStartSeconds)
                if time.seconds >= self.trimEndSeconds - 0.03 {
                    self.seekToStart()
                }
            }
        }
        player.play()
    }

    private func seekToStart() {
        player.seek(
            to: CMTime(seconds: trimStartSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    // MARK: - 疊圖座標

    /// 影片在容器中 aspect-fit 顯示的區域（與 `VideoLayerView` 的 `.resizeAspect` 一致）。
    func imageRect(containerSize: CGSize) -> CGRect {
        let rect = PlateCoordinates.aspectFitRect(
            containerWidth: Double(containerSize.width),
            containerHeight: Double(containerSize.height),
            imageWidth: Double(geometry.widthPx),
            imageHeight: Double(geometry.heightPx)
        )
        return CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    /// 把一個樣本（Vision 正規化，原點左下）換算成顯示座標（原點左上）。
    func point(for sample: TrackSample, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + sample.x * rect.width,
            y: rect.minY + (1 - sample.y) * rect.height
        )
    }

    /// 整條軌跡的顯示座標點（給軌跡線用）。
    func trajectoryPoints(in rect: CGRect) -> [CGPoint] {
        samples.map { point(for: $0, in: rect) }
    }

    /// 最接近目前播放時間的樣本（給追蹤點用）。
    func currentSample() -> TrackSample? {
        samples.min {
            abs($0.time - currentTimeInClip) < abs($1.time - currentTimeInClip)
        }
    }
}
