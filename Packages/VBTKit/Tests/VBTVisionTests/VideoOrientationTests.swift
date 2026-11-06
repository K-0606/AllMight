import Testing
import Foundation
import CoreGraphics
@testable import VBTVision

@Test("identity transform 判為 .up")
func orientationUp() {
    #expect(VideoOrientation.from(transform: .identity) == .up)
}

@Test("90° 旋轉（直拍）判為 .right")
func orientationRight() {
    #expect(VideoOrientation.from(transform: CGAffineTransform(rotationAngle: .pi / 2)) == .right)
}

@Test("180° 旋轉判為 .down")
func orientationDown() {
    #expect(VideoOrientation.from(transform: CGAffineTransform(rotationAngle: .pi)) == .down)
}

@Test("−90° 旋轉判為 .left")
func orientationLeft() {
    #expect(VideoOrientation.from(transform: CGAffineTransform(rotationAngle: -.pi / 2)) == .left)
}

@Test("行列式為負的 transform 判為鏡像變體")
func orientationMirrored() {
    // Rθ·水平翻轉，θ = 0：a=−1, d=1 → .upMirrored
    let flipUp = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
    #expect(VideoOrientation.from(transform: flipUp) == .upMirrored)
    #expect(VideoOrientation.from(transform: flipUp).isMirrored)

    // θ = 90：a=0, b=−1, c=−1, d=0 → .rightMirrored
    let flipRight = CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: 0, ty: 0)
    #expect(VideoOrientation.from(transform: flipRight) == .rightMirrored)
}

@Test("非鏡像方向的 isMirrored 為 false")
func nonMirroredFlag() {
    #expect(!VideoOrientation.up.isMirrored)
    #expect(!VideoOrientation.right.isMirrored)
}
