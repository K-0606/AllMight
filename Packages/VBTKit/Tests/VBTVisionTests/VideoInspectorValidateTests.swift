import Testing
import Foundation
import VBTCore
@testable import VBTVision

private let limits = VideoImportLimits.standard

@Test("正常影片通過檢查")
func validatePasses() {
    #expect(VideoInspector.validate(durationSeconds: 2, fps: 60, hasTimeRemappedSegments: false, limits: limits) == nil)
}

@Test("fps 高於 120 判為慢動作")
func validateHighFPSSlowMotion() {
    #expect(VideoInspector.validate(durationSeconds: 2, fps: 240, hasTimeRemappedSegments: false, limits: limits) == .unsupportedSlowMotion)
}

@Test("有時間變速片段判為慢動作")
func validateTimeRemappedSlowMotion() {
    #expect(VideoInspector.validate(durationSeconds: 2, fps: 30, hasTimeRemappedSegments: true, limits: limits) == .unsupportedSlowMotion)
}

@Test("fps 低於 24 判為影格率過低")
func validateLowFrameRate() {
    #expect(VideoInspector.validate(durationSeconds: 2, fps: 20, hasTimeRemappedSegments: false, limits: limits) == .frameRateTooLow(20))
}

@Test("長度短於 1 秒判為太短")
func validateTooShort() {
    #expect(VideoInspector.validate(durationSeconds: 0.5, fps: 60, hasTimeRemappedSegments: false, limits: limits) == .videoTooShort(seconds: 0.5))
}

@Test("長度超過 3 分鐘判為太長")
func validateTooLong() {
    #expect(VideoInspector.validate(durationSeconds: 200, fps: 60, hasTimeRemappedSegments: false, limits: limits) == .videoTooLong(seconds: 200))
}

@Test("時長非有限值判為無法讀取")
func validateNonFiniteDuration() {
    #expect(VideoInspector.validate(durationSeconds: .nan, fps: 60, hasTimeRemappedSegments: false, limits: limits) == .videoUnreadable)
    #expect(VideoInspector.validate(durationSeconds: 2, fps: .infinity, hasTimeRemappedSegments: false, limits: limits) == .videoUnreadable)
}

@Test("30 fps 可通過但標記為低影格率")
func validateThirtyFPSPassesAsLow() {
    #expect(VideoInspector.validate(durationSeconds: 2, fps: 30, hasTimeRemappedSegments: false, limits: limits) == nil)
    #expect(30 < limits.recommendedFrameRate)
}
