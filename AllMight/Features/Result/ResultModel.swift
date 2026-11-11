import Foundation
import Observation
import AVFoundation
import CoreGraphics
import VBTCore
import VBTVision

/// 結果頁播放器的狀態：以剪好的片段迴圈重播，並把 `series` 重建成螢幕上的槓鈴軌跡線（Q4）。
///
/// `series` 的位置是「相對第一個樣本」的公尺（`scale` 為 m/px），第一個樣本約等於使用者圈選的
/// 槓片中心，故以 `selection.center` 為錨點，用 `scale` 與 `geometry` 反推回 Vision 正規化座標，
/// 再換算成顯示座標（與 `TrackingPreview` 的對應方式一致）。
@MainActor
@Observable
final class ResultModel {
    let player: AVPlayer

    private let trimStartSeconds: Double
    private let trimEndSeconds: Double
    private let geometry: VideoGeometry
    private let selection: PlateSelection
    private let series: KinematicSeries
    private var timeObserver: Any?

    init(context: ResultContext) {
        self.player = AVPlayer(url: context.videoURL)
        self.trimStartSeconds = context.trimStartSeconds
        self.trimEndSeconds = context.trimEndSeconds
        self.geometry = context.geometry
        self.selection = context.selection
        self.series = context.analysis.series
    }

    /// 開始迴圈重播片段。
    func start() {
        player.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimEndSeconds, preferredTimescale: 600)
        seekToStart()
        let interval = CMTime(seconds: 1.0 / 30, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                if time.seconds >= self.trimEndSeconds - 0.03 {
                    self.seekToStart()
                }
            }
        }
        player.play()
    }

    /// 停止重播並移除觀察者（離開畫面時呼叫）。
    func stop() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player.pause()
    }

    func togglePlayback() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            if player.currentTime().seconds >= trimEndSeconds - 0.05 {
                seekToStart()
            }
            player.play()
        }
    }

    private func seekToStart() {
        player.seek(
            to: CMTime(seconds: trimStartSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    // MARK: - 軌跡線

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

    /// 由 `series` 重建的軌跡線顯示座標點（原點左上）。
    func trajectoryPoints(in rect: CGRect) -> [CGPoint] {
        let scale = series.scale
        let w = Double(geometry.widthPx)
        let h = Double(geometry.heightPx)
        guard scale > 0, w > 0, h > 0 else { return [] }
        let count = min(series.position.count, series.horizontalPosition.count)
        var points: [CGPoint] = []
        points.reserveCapacity(count)
        for i in 0..<count {
            // 公尺 → 像素 → Vision 正規化（以圈選中心為錨點）→ 顯示座標。
            let normX = selection.centerX + (series.horizontalPosition[i] / scale) / w
            let normY = selection.centerY + (series.position[i] / scale) / h
            points.append(CGPoint(
                x: rect.minX + normX * rect.width,
                y: rect.minY + (1 - normY) * rect.height
            ))
        }
        return points
    }
}
