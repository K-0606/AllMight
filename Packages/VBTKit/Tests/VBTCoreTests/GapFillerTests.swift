import Testing
import Foundation
@testable import VBTCore

/// 缺漏內插測試（docs/ALGORITHMS.md §3）。邊界：缺漏 = maxGapFrames 與 +1。
@Suite("缺漏內插")
struct GapFillerTests {
    let tol = 1e-9

    /// 以固定間隔、線性遞增的 y 建樣本；指定索引設為低信心（缺漏）。
    func makeSamples(count: Int, gapIndices: Set<Int>, slope: Double = 1.0) -> [CalibratedSample] {
        (0..<count).map { i in
            CalibratedSample(
                time: Double(i) * 0.1,
                x: 0,
                y: slope * Double(i) * 0.1,
                confidence: gapIndices.contains(i) ? 0.1 : 0.9
            )
        }
    }

    @Test("內部單點缺漏線性內插補回")
    func interpolateSinglePoint() throws {
        var s = makeSamples(count: 5, gapIndices: [2])
        // 把缺漏點的 y 設成亂值，確認被內插覆蓋
        s[2].y = -999
        let out = try GapFiller.fill(s, minConfidence: 0.3, maxGapFrames: 6)
        #expect(out.count == 5)
        // 線性訊號內插回原值 0.2
        #expect(abs(out[2].y - 0.2) < tol)
        #expect(out[2].confidence == Float(0.3))
    }

    @Test("連續缺漏 = maxGapFrames 可內插")
    func gapEqualsMaxInterpolates() throws {
        // 10 點，索引 2...7 共 6 個缺漏，maxGapFrames = 6
        let s = makeSamples(count: 10, gapIndices: [2, 3, 4, 5, 6, 7])
        let out = try GapFiller.fill(s, minConfidence: 0.3, maxGapFrames: 6)
        #expect(out.count == 10)
        for k in 2...7 {
            #expect(abs(out[k].y - Double(k) * 0.1) < tol)
        }
    }

    @Test("連續缺漏 = maxGapFrames + 1 丟 trackingLost")
    func gapExceedsMaxThrows() {
        // 索引 2...8 共 7 個缺漏，maxGapFrames = 6
        let s = makeSamples(count: 11, gapIndices: [2, 3, 4, 5, 6, 7, 8])
        #expect(throws: AnalysisError.trackingLost(atTime: 0.2)) {
            try GapFiller.fill(s, minConfidence: 0.3, maxGapFrames: 6)
        }
    }

    @Test("開頭缺漏（無前點）被丟棄，網格晚一點開始")
    func leadingGapDropped() throws {
        let s = makeSamples(count: 6, gapIndices: [0, 1])
        let out = try GapFiller.fill(s, minConfidence: 0.3, maxGapFrames: 6)
        #expect(out.count == 4)
        #expect(abs(out[0].time - 0.2) < tol)
    }

    @Test("結尾缺漏（無後點）被丟棄")
    func trailingGapDropped() throws {
        let s = makeSamples(count: 6, gapIndices: [4, 5])
        let out = try GapFiller.fill(s, minConfidence: 0.3, maxGapFrames: 6)
        #expect(out.count == 4)
        #expect(abs(out.last!.time - 0.3) < tol)
    }

    @Test("沒有缺漏時原樣回傳")
    func noGaps() throws {
        let s = makeSamples(count: 5, gapIndices: [])
        let out = try GapFiller.fill(s, minConfidence: 0.3, maxGapFrames: 6)
        #expect(out.count == 5)
        #expect(out == s)
    }
}
