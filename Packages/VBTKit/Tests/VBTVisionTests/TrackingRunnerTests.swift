import Testing
import Foundation
import CoreGraphics
import VBTCore
@testable import VBTVision

/// TrackingRunner 端對端：把合成影片跑成 TrackSample，確認樣本數、軌跡與跟丟回報。
@Suite("TrackingRunner")
struct TrackingRunnerTests {
    @Test("無遮擋：樣本數接近幀數、軌跡貼合真實中心、未跟丟")
    func runProducesTrajectory() async throws {
        let width = 360, height = 640, fps = 60
        let centers = SyntheticPlateVideo.verticalSinusoidCenters(
            count: 240, width: width, height: height, margin: 160
        )
        let video = try await SyntheticPlateVideo.make(
            orientedWidth: width, orientedHeight: height,
            centersPx: centers, diameterPx: 110, fps: fps
        )
        defer { try? FileManager.default.removeItem(at: video.url) }

        let run = try await TrackingRunner().run(
            url: video.url,
            trimStartSeconds: 0,
            trimEndSeconds: Double(centers.count) / Double(fps) + 0.2,
            selection: PlateSelection(
                centerX: centers[0].x / Double(width),
                centerY: 1 - centers[0].y / Double(height),
                diameterPx: 110
            )
        )

        #expect(run.lostAtTime == nil)
        #expect(abs(run.samples.count - centers.count) <= 2)
        #expect(run.meanConfidence > 0.5)

        // 每個樣本換回像素，對照 ground truth（容差放寬到 3 px，含 Vision 底噪，見 D-023）。
        for (i, sample) in run.samples.enumerated() where i < centers.count {
            let px = sample.x * Double(width)
            let py = (1 - sample.y) * Double(height)
            #expect(hypot(px - centers[i].x, py - centers[i].y) < 3.0)
        }
    }

    @Test("長時間遮擋：回報 lostAtTime，不丟錯")
    func runReportsTrackingLost() async throws {
        let width = 360, height = 640, fps = 60, frameCount = 120
        let centers = SyntheticPlateVideo.verticalSinusoidCenters(
            count: frameCount, width: width, height: height, margin: 120
        )
        let video = try await SyntheticPlateVideo.make(
            orientedWidth: width, orientedHeight: height,
            centersPx: centers, diameterPx: 110, fps: fps,
            occludedFrames: Set(40..<70)
        )
        defer { try? FileManager.default.removeItem(at: video.url) }

        let run = try await TrackingRunner().run(
            url: video.url,
            trimStartSeconds: 0,
            trimEndSeconds: 2,
            selection: PlateSelection(
                centerX: centers[0].x / Double(width),
                centerY: 1 - centers[0].y / Double(height),
                diameterPx: 110
            )
        )

        let lost = try #require(run.lostAtTime, "長遮擋應回報跟丟時間")
        #expect(lost > 0)
        #expect(lost <= 2)
    }
}
