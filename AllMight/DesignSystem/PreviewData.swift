import Foundation
import VBTCore
import VBTVision

/// SwiftUI `#Preview` 用的假資料（見 .claude/rules/swiftui-app.md）。
///
/// 只在預覽與元件示意用，不進入正式流程。3 下、向心 MV 0.28 / 0.25 / 0.24 m/s。
enum PreviewData {
    /// 假的 3 下分析結果。
    static let analysis = SetAnalysis(
        analysisVersion: 1,
        parameters: .standard,
        reps: [
            RepMetrics(
                index: 1,
                concentric: PhaseMetrics(duration: 0.60, meanVelocity: 0.28, peakVelocity: 0.55, displacement: 0.45),
                eccentric: PhaseMetrics(duration: 0.80, meanVelocity: 0.22, peakVelocity: 0.40, displacement: 0.45),
                mpv: 0.30,
                restAfter: 1.40,
                dropFromFirst: nil
            ),
            RepMetrics(
                index: 2,
                concentric: PhaseMetrics(duration: 0.64, meanVelocity: 0.25, peakVelocity: 0.50, displacement: 0.44),
                eccentric: PhaseMetrics(duration: 0.82, meanVelocity: 0.20, peakVelocity: 0.37, displacement: 0.44),
                mpv: 0.27,
                restAfter: 1.40,
                dropFromFirst: (0.25 - 0.28) / 0.28
            ),
            RepMetrics(
                index: 3,
                concentric: PhaseMetrics(duration: 0.66, meanVelocity: 0.24, peakVelocity: 0.48, displacement: 0.43),
                eccentric: PhaseMetrics(duration: 0.85, meanVelocity: 0.19, peakVelocity: 0.35, displacement: 0.43),
                mpv: 0.26,
                restAfter: nil,
                dropFromFirst: (0.24 - 0.28) / 0.28
            ),
        ],
        summary: SetSummary(
            repCount: 3,
            meanVelocity: (0.28 + 0.25 + 0.24) / 3,
            peakVelocity: 0.55,
            meanROM: (0.45 + 0.44 + 0.43) / 3,
            velocityLoss: (0.28 - 0.24) / 0.28
        ),
        series: series
    )

    /// 3 個向心凸波 + 其間離心的合成速度序列，供速度曲線預覽。
    static let series: KinematicSeries = {
        let dt = 1.0 / 60.0
        let count = 360                 // 6 秒
        let centers = [1.0, 3.0, 5.0]   // 三下的向心中心（秒）
        let peaks = [0.55, 0.50, 0.48]
        let halfWidth = 0.30

        var time: [Double] = []
        var velocity: [Double] = []
        var horizontal: [Double] = []
        for i in 0..<count {
            let t = Double(i) * dt
            var v = 0.0
            for (center, peak) in zip(centers, peaks) {
                // 向心正凸波。
                if abs(t - center) <= halfWidth {
                    v += peak * cos((t - center) / halfWidth * (.pi / 2))
                }
                // 向心前的離心負凸波。
                let eccCenter = center - 0.9
                if abs(t - eccCenter) <= halfWidth {
                    v -= peak * 0.7 * cos((t - eccCenter) / halfWidth * (.pi / 2))
                }
            }
            time.append(t)
            velocity.append(v)
            horizontal.append(0.01 * sin(t * 2))
        }
        // 位置為速度的累積積分。
        var position: [Double] = []
        var running = 0.0
        for v in velocity {
            running += v * dt
            position.append(running)
        }
        let acceleration = stride(from: 0, to: count, by: 1).map { i -> Double in
            guard i > 0, i < count - 1 else { return 0 }
            return (velocity[i + 1] - velocity[i - 1]) / (2 * dt)
        }
        return KinematicSeries(
            dt: dt,
            time: time,
            position: position,
            velocity: velocity,
            acceleration: acceleration,
            horizontalPosition: horizontal,
            scale: 0.0016
        )
    }()

    /// 假的槓片選取（約在畫面中央）。
    static let selection = PlateSelection(centerX: 0.5, centerY: 0.45, diameterPx: 280)

    /// 假的影片片段（直拍 1080×1920、60fps）。URL 僅供型別，不實際播放。
    static let clip = VideoClip(
        url: URL(fileURLWithPath: "/dev/null"),
        info: VideoInfo(
            durationSeconds: 6,
            geometry: VideoGeometry(widthPx: 1080, heightPx: 1920, nominalFPS: 60),
            orientation: .up,
            isLowFrameRate: false,
            codec: "hvc1",
            isHDR: false
        )
    )
}
