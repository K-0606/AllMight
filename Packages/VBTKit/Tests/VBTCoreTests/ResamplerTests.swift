import Testing
import Foundation
@testable import VBTCore

/// 等間隔重新取樣測試（docs/ALGORITHMS.md §3）。
@Suite("重新取樣")
struct ResamplerTests {
    let tol = 1e-9

    @Test("已是等間隔時取樣點對齊原值")
    func uniformInputIdentity() {
        let s = (0..<5).map { CalibratedSample(time: Double($0) * 0.1, x: 0, y: Double($0), confidence: 1) }
        let g = Resampler.resample(s, dt: 0.1)
        #expect(g.time.count == 5)
        for i in 0..<5 {
            #expect(abs(g.time[i] - Double(i) * 0.1) < tol)
            #expect(abs(g.y[i] - Double(i)) < tol)
        }
    }

    @Test("變動影格率線性訊號重取樣後仍精確")
    func variableRateLinear() {
        // 時間戳不等間隔，y = 2·t 線性。重取樣到 dt=0.05 後每點應為 2·t。
        let times = [0.0, 0.07, 0.11, 0.2, 0.26, 0.4]
        let s = times.map { CalibratedSample(time: $0, x: 0, y: 2 * $0, confidence: 1) }
        let g = Resampler.resample(s, dt: 0.05)
        for i in 0..<g.time.count {
            #expect(abs(g.y[i] - 2 * g.time[i]) < tol)
        }
    }

    @Test("取樣點落在原樣本之間時線性內插")
    func midpointInterpolation() {
        let s = [
            CalibratedSample(time: 0, x: 0, y: 0, confidence: 1),
            CalibratedSample(time: 0.1, x: 0, y: 1, confidence: 1),
        ]
        let g = Resampler.resample(s, dt: 0.05)
        // t = 0, 0.05, 0.1 → y = 0, 0.5, 1
        #expect(g.time.count == 3)
        #expect(abs(g.y[1] - 0.5) < tol)
    }

    @Test("span 剛好是 dt 整數倍時尾幀不被浮點誤差掉掉")
    func integerSpanKeepsLastFrame() {
        // 0.3 / 0.1 = 3（浮點上是 2.999…）：應得 4 點，尾端貼齊 0.3。
        let s = [
            CalibratedSample(time: 0, x: 0, y: 0, confidence: 1),
            CalibratedSample(time: 0.3, x: 0, y: 3, confidence: 1),
        ]
        let g = Resampler.resample(s, dt: 0.1)
        #expect(g.time.count == 4)
        #expect(abs(g.time.last! - 0.3) < tol)
        #expect(abs(g.y.last! - 3) < tol)
    }

    @Test("網格不超過最後一個樣本時間")
    func gridWithinRange() {
        let s = [
            CalibratedSample(time: 0, x: 0, y: 0, confidence: 1),
            CalibratedSample(time: 0.35, x: 0, y: 3.5, confidence: 1),
        ]
        let g = Resampler.resample(s, dt: 0.1)
        #expect(g.time.last! <= 0.35 + tol)
    }

    @Test("少於兩點時原樣回傳")
    func singleSample() {
        let s = [CalibratedSample(time: 0.5, x: 1, y: 2, confidence: 1)]
        let g = Resampler.resample(s, dt: 0.1)
        #expect(g.time == [0.5])
        #expect(g.y == [2])
    }
}
