import SwiftUI
import AVFoundation
import UIKit

/// 用 `AVPlayerLayer` 顯示影片（無控制列、`.resizeAspect`），讓上層能用相同的 aspect-fit 區域疊圖。
///
/// 影片以 aspect-fit 填滿 view bounds，顯示區域即 `PlateCoordinates.aspectFitRect(container, 影片幾何)`，
/// 疊圖的追蹤點據此換算。
struct VideoLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }

    /// 以子圖層方式持有 `AVPlayerLayer`（避免 `layer as!` 強制轉型）。
    final class PlayerContainerView: UIView {
        let playerLayer = AVPlayerLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resizeAspect
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { nil }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}
