import Foundation
import os
import VBTCore

/// 一次追蹤執行的結果（值型別，可跨 actor 傳遞）。
public struct TrackingRun: Sendable {
    /// 每幀的追蹤樣本（Vision 正規化座標，見 docs/ALGORITHMS.md §0）；缺漏的幀不含在內。
    public var samples: [TrackSample]
    /// 若中途跟丟，記錄跟丟時間（秒，相對片段起點）；否則為 nil。
    public var lostAtTime: Double?
    /// 讀到的總幀數。
    public var frameCount: Int
    /// 有效樣本的平均信心。
    public var meanConfidence: Double
    /// 轉正後的影片幾何（尺寸與 nominalFPS），供後續運動學計算使用。
    public var geometry: VideoGeometry

    public init(
        samples: [TrackSample],
        lostAtTime: Double?,
        frameCount: Int,
        meanConfidence: Double,
        geometry: VideoGeometry
    ) {
        self.samples = samples
        self.lostAtTime = lostAtTime
        self.frameCount = frameCount
        self.meanConfidence = meanConfidence
        self.geometry = geometry
    }
}

/// 把影片片段跑過 `FrameReader → PlateTracker`，產生 `[TrackSample]`（見 docs/ARCHITECTURE.md §3、§5）。
///
/// 這是 M4 `AnalysisPipeline` 會重用的追蹤段；目前先供「追蹤驗證」畫面目視確認追蹤是否正確。
/// Vision / AVFoundation 物件只在本 actor 內建立與使用，不跨 actor 傳遞；對外只回傳 `Sendable` 值。
/// 追蹤跟丟時**不丟錯**，而是停止並在 `TrackingRun.lostAtTime` 記錄時間，讓呼叫端能看到跟丟在哪。
public actor TrackingRunner {
    private static let logger = Logger(subsystem: "com.kun0606.AllMight", category: "Tracking")

    public init() {}

    /// `onProgress`（選用）每讀一幀以估計的追蹤進度（0…1）回呼，供 `AnalysisPipeline` 轉成進度串流。
    public func run(
        url: URL,
        trimStartSeconds: Double,
        trimEndSeconds: Double,
        selection: PlateSelection,
        parameters: AnalysisParameters = .standard,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> TrackingRun {
        Self.logger.info("追蹤開始 片段=\(trimStartSeconds, privacy: .public)…\(trimEndSeconds, privacy: .public)s 圓心=(\(selection.centerX, privacy: .public), \(selection.centerY, privacy: .public)) 直徑px=\(selection.diameterPx, privacy: .public) minConf=\(parameters.minConfidence, privacy: .public) maxGap=\(parameters.maxGapFrames, privacy: .public)")

        let reader = try await FrameReader(
            url: url,
            trimStartSeconds: trimStartSeconds,
            trimEndSeconds: trimEndSeconds
        )
        Self.logger.info("影片幾何 \(reader.geometry.widthPx, privacy: .public)x\(reader.geometry.heightPx, privacy: .public) fps=\(reader.geometry.nominalFPS, privacy: .public) 方向=\(String(describing: reader.orientation), privacy: .public)")

        let tracker = PlateTracker(selection: selection, geometry: reader.geometry, parameters: parameters)

        // 估計總幀數（片段長度 × fps），用來換算進度；實際幀數以 reader 為準，進度上限夾到 1。
        let estimatedFrames = max(1.0, ((trimEndSeconds - trimStartSeconds) * reader.geometry.nominalFPS).rounded())

        var samples: [TrackSample] = []
        var confidenceSum = 0.0
        var frameCount = 0
        var lostAtTime: Double?

        do {
            while let frame = try reader.next() {
                try Task.checkCancellation()
                frameCount += 1
                onProgress?(min(1.0, Double(frameCount) / estimatedFrames))
                if let sample = try tracker.track(frame) {
                    samples.append(sample)
                    confidenceSum += Double(sample.confidence)
                    Self.logger.debug("f\(frameCount, privacy: .public) t=\(sample.time, privacy: .public) x=\(sample.x, privacy: .public) y=\(sample.y, privacy: .public) conf=\(sample.confidence, privacy: .public)")
                } else {
                    Self.logger.debug("f\(frameCount, privacy: .public) t=\(frame.time, privacy: .public) 缺漏")
                }
            }
        } catch let AnalysisError.trackingLost(atTime: time) {
            lostAtTime = time
            reader.cancel()
            Self.logger.warning("追蹤跟丟 t=\(time, privacy: .public)s（已讀 \(frameCount, privacy: .public) 幀、\(samples.count, privacy: .public) 樣本）")
        } catch is CancellationError {
            reader.cancel()
            Self.logger.info("追蹤取消（已讀 \(frameCount, privacy: .public) 幀）")
            throw AnalysisError.cancelled
        }

        let meanConfidence = samples.isEmpty ? 0 : confidenceSum / Double(samples.count)
        Self.logger.info("追蹤結束 幀=\(frameCount, privacy: .public) 樣本=\(samples.count, privacy: .public) 平均信心=\(meanConfidence, privacy: .public) 跟丟=\(lostAtTime != nil, privacy: .public)")

        return TrackingRun(
            samples: samples,
            lostAtTime: lostAtTime,
            frameCount: frameCount,
            meanConfidence: meanConfidence,
            geometry: reader.geometry
        )
    }
}
