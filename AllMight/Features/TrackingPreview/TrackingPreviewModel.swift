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
    /// 追蹤框寬中位數與使用者圈差太多（§1 scaleMismatch）：圈可能沒貼齊槓片，建議重畫（非阻擋性，見 D-029）。
    private(set) var scaleMismatch = false
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
            scaleMismatch = Calibrator.scaleMismatch(
                samples: run.samples, selection: selection, geometry: geometry
            )
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
        displayPoint(x: sample.x, y: sample.y, in: rect)
    }

    /// 把正規化座標（原點左下）換算成顯示座標（原點左上）。
    private func displayPoint(x: Double, y: Double, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + x * rect.width,
            y: rect.minY + (1 - y) * rect.height
        )
    }

    /// 平滑後的軌跡顯示座標點（給軌跡線用）。對樣本的正規化座標做置中移動平均，
    /// 只影響畫面呈現、**不進任何速度/ROM 計算**（見 DECISIONS D-029：圈畫大時追蹤框中心
    /// 每幀漂移造成軌跡線左右抖，平滑僅為觀感）。
    func trajectoryPoints(in rect: CGRect) -> [CGPoint] {
        TrackingPreviewModel.movingAverage(samples, window: Self.trajectorySmoothingWindow)
            .map { displayPoint(x: $0.x, y: $0.y, in: rect) }
    }

    /// 軌跡線平滑的置中移動平均視窗（奇數；純視覺，見 D-029）。
    private static let trajectorySmoothingWindow = 5

    /// 對樣本的正規化座標做置中移動平均。樣本太少或視窗 ≤ 1 時原樣返回。
    private static func movingAverage(_ samples: [TrackSample], window: Int) -> [(x: Double, y: Double)] {
        guard samples.count > 2, window > 1 else { return samples.map { ($0.x, $0.y) } }
        let half = window / 2
        return samples.indices.map { i in
            let lo = max(0, i - half)
            let hi = min(samples.count - 1, i + half)
            var sumX = 0.0, sumY = 0.0
            for j in lo...hi {
                sumX += samples[j].x
                sumY += samples[j].y
            }
            let n = Double(hi - lo + 1)
            return (sumX / n, sumY / n)
        }
    }

    /// 最接近目前播放時間的樣本（給追蹤點用）。
    func currentSample() -> TrackSample? {
        samples.min {
            abs($0.time - currentTimeInClip) < abs($1.time - currentTimeInClip)
        }
    }
}
