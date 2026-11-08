import Foundation

/// 把原始追蹤樣本轉成等間隔的運動學序列（docs/ALGORITHMS.md §1–4）。
///
/// 串起 M3 各步驟：校正（§1–2）→ 缺漏內插（§3 步驟 1–2）→ 等間隔重取樣（§3 步驟 3）
/// → Savitzky-Golay 平滑與一、二階導數（§4）。次數切分與指標在 M4（`RepSegmenter`、
/// `MetricsCalculator`）接在這之後。純函式，可在 macOS `swift test`。
public enum Kinematics {
    /// 計算運動學序列。缺漏超過 `maxGapFrames` 時丟 `AnalysisError.trackingLost`。
    public static func computeSeries(
        samples: [TrackSample],
        selection: PlateSelection,
        geometry: VideoGeometry,
        plateDiameterCm: Double,
        parameters: AnalysisParameters
    ) throws -> KinematicSeries {
        let scale = Calibrator.scale(plateDiameterCm: plateDiameterCm, selection: selection)
        let fps = geometry.nominalFPS
        guard fps > 0 else {
            return KinematicSeries(
                dt: 0, time: [], position: [], velocity: [], acceleration: [],
                horizontalPosition: [], scale: scale
            )
        }
        let dt = 1.0 / fps

        let calibrated = Calibrator.calibrate(
            samples: samples, selection: selection, geometry: geometry, plateDiameterCm: plateDiameterCm
        )
        let filled = try GapFiller.fill(
            calibrated, minConfidence: parameters.minConfidence, maxGapFrames: parameters.maxGapFrames
        )
        let grid = Resampler.resample(filled, dt: dt)
        guard !grid.time.isEmpty else {
            return KinematicSeries(
                dt: dt, time: [], position: [], velocity: [], acceleration: [],
                horizontalPosition: [], scale: scale
            )
        }

        let h = SavitzkyGolay.halfWindow(windowSeconds: parameters.sgWindowSeconds, fps: fps)
        let sg = SavitzkyGolay(halfWindow: h, order: parameters.sgOrder)

        return KinematicSeries(
            dt: dt,
            time: grid.time,
            position: sg.smooth(grid.y),
            velocity: sg.firstDerivative(grid.y, dt: dt),
            acceleration: sg.secondDerivative(grid.y, dt: dt),
            horizontalPosition: sg.smooth(grid.x),
            scale: scale
        )
    }
}
