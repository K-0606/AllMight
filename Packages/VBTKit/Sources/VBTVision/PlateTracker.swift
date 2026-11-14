import Foundation
import Vision
import CoreGraphics
import VBTCore

/// 用 Vision `VNTrackObjectRequest` 逐幀追蹤槓片中心（見 skill plate-tracking）。
///
/// 只用追蹤框**中心點**（框大小會漂移，比例尺用使用者圓圈，見 DECISIONS D-006）。
/// 輸出 `TrackSample` 的座標為 Vision 正規化（0–1，原點左下，轉正後影像；見 docs/ALGORITHMS.md §0）。
///
/// 非 `Sendable`：Vision 物件只在單一 context（未來的 `AnalysisPipeline` actor）內建立與使用，
/// 不跨 actor 傳遞（見 docs/ARCHITECTURE.md §5）。
final class PlateTracker {
    private let handler = VNSequenceRequestHandler()
    private let request: VNTrackObjectRequest
    private let selection: PlateSelection
    private let geometry: VideoGeometry
    private let parameters: AnalysisParameters

    /// 初始框的正規化面積（寬 × 高），作為面積漂移判斷的基準。
    private let initialArea: Double
    /// 追蹤框中心跳動上限（像素）。
    private let maxCenterJumpPx: Double

    private var isFirstFrame = true
    private var lastGoodCenter: CGPoint
    private var consecutiveMisses = 0

    init(selection: PlateSelection, geometry: VideoGeometry, parameters: AnalysisParameters = .standard) {
        self.selection = selection
        self.geometry = geometry
        self.parameters = parameters

        let initialBox = PlateTracker.initialBoundingBox(selection: selection, geometry: geometry)
        let observation = VNDetectedObjectObservation(boundingBox: initialBox)
        let request = VNTrackObjectRequest(detectedObjectObservation: observation)
        request.trackingLevel = .accurate
        self.request = request

        self.initialArea = Double(initialBox.width * initialBox.height)
        self.maxCenterJumpPx = parameters.maxCenterJumpFactor * selection.diameterPx
        self.lastGoodCenter = CGPoint(x: selection.centerX, y: selection.centerY)
    }

    /// 追蹤一幀。
    ///
    /// 回傳 `nil` 代表這一幀視為缺漏（信心過低、瞬移、框面積異常）。
    /// 連續缺漏超過 `maxGapFrames` 時丟出 `AnalysisError.trackingLost(atTime:)`。
    /// 第一幀直接回傳使用者圓心（信心 1.0），並用該幀初始化追蹤器。
    func track(_ frame: Frame) throws -> TrackSample? {
        try handler.perform([request], on: frame.pixelBuffer, orientation: frame.orientation)
        let observation = request.results?.first as? VNDetectedObjectObservation

        if isFirstFrame {
            isFirstFrame = false
            if let observation { request.inputObservation = observation }
            lastGoodCenter = CGPoint(x: selection.centerX, y: selection.centerY)
            return TrackSample(time: frame.time, x: selection.centerX, y: selection.centerY, confidence: 1)
        }

        // 完全沒有結果：缺漏，嘗試從上一個好位置接回。
        guard let observation else {
            request.inputObservation = reacquireObservation()
            return try registerMiss(at: frame.time)
        }

        let box = observation.boundingBox
        let center = CGPoint(x: box.midX, y: box.midY)
        let lowConfidence = observation.confidence < Float(parameters.minConfidence)

        // 不合物理的瞬移（像素空間）。
        let dx = Double(center.x - lastGoodCenter.x) * Double(geometry.widthPx)
        let dy = Double(center.y - lastGoodCenter.y) * Double(geometry.heightPx)
        let jumped = hypot(dx, dy) > maxCenterJumpPx

        // 框面積相對初始框異常膨脹／縮小。
        let area = Double(box.width * box.height)
        let areaOutOfRange = initialArea > 0
            && (area > parameters.maxAreaGrowthFactor * initialArea
                || area < parameters.minAreaShrinkFactor * initialArea)

        if lowConfidence || jumped || areaOutOfRange {
            // 框爆掉／縮掉時重設到「上一個好位置 + 初始框大小」嘗試接回（skill plate-tracking §3）；
            // 其餘缺漏（信心過低、瞬移）餵回當前觀測，讓追蹤器自然延續——遮擋時信心會持續偏低，
            // 缺漏才會累積觸發 trackingLost，而不是因為重設成高信心的假框被接回。
            request.inputObservation = areaOutOfRange ? reacquireObservation() : observation
            return try registerMiss(at: frame.time)
        }

        consecutiveMisses = 0
        lastGoodCenter = center
        request.inputObservation = observation
        return TrackSample(
            time: frame.time,
            x: Double(center.x),
            y: Double(center.y),
            confidence: observation.confidence,
            // Vision 正規化框寬，供 scaleMismatch 警告（§1）；首幀回傳的是使用者圈、不帶框寬。
            boxWidth: Double(box.width)
        )
    }

    /// 記一次缺漏；超過 `maxGapFrames` 丟 `trackingLost`。`inputObservation` 由呼叫端先設好。
    private func registerMiss(at time: Double) throws -> TrackSample? {
        consecutiveMisses += 1
        if consecutiveMisses > parameters.maxGapFrames {
            throw AnalysisError.trackingLost(atTime: time)
        }
        return nil
    }

    /// 以「上一個好位置 + 初始框大小」建出觀測，供框異常時嘗試接回。
    private func reacquireObservation() -> VNDetectedObjectObservation {
        VNDetectedObjectObservation(
            boundingBox: PlateTracker.boundingBox(center: lastGoodCenter, selection: selection, geometry: geometry)
        )
    }

    /// 初始追蹤框：以使用者圓心為中心、邊長 = 圓片直徑的正方形，轉成 Vision 正規化 `CGRect`，夾在 0–1。
    static func initialBoundingBox(selection: PlateSelection, geometry: VideoGeometry) -> CGRect {
        boundingBox(
            center: CGPoint(x: selection.centerX, y: selection.centerY),
            selection: selection,
            geometry: geometry
        )
    }

    /// 以指定正規化中心、圓片直徑建出正方形 Vision 正規化框，夾在 0–1 內。
    private static func boundingBox(center: CGPoint, selection: PlateSelection, geometry: VideoGeometry) -> CGRect {
        let widthN = geometry.widthPx > 0 ? selection.diameterPx / Double(geometry.widthPx) : 0
        let heightN = geometry.heightPx > 0 ? selection.diameterPx / Double(geometry.heightPx) : 0
        let originX = min(max(center.x - widthN / 2, 0), max(0, 1 - widthN))
        let originY = min(max(center.y - heightN / 2, 0), max(0, 1 - heightN))
        return CGRect(x: originX, y: originY, width: min(widthN, 1), height: min(heightN, 1))
    }
}
