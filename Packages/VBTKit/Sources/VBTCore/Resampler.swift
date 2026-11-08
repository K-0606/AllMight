import Foundation

/// 等間隔重新取樣（docs/ALGORITHMS.md §3 步驟 3）。純函式。
///
/// 手機影片可能是變動影格率；依時間戳線性內插到 `dt = 1 / nominalFPS` 的等間隔網格。
/// 輸入樣本的時間必須遞增。回傳三條等長序列：時間、水平位置、垂直位置（公尺）。
public enum Resampler {
    /// 等間隔取樣結果。
    public struct Grid: Sendable, Equatable {
        /// 取樣間隔（秒）。
        public var dt: Double
        /// 等間隔時間（秒）。
        public var time: [Double]
        /// 水平位置（公尺）。
        public var x: [Double]
        /// 垂直位置（公尺）。
        public var y: [Double]
    }

    public static func resample(_ samples: [CalibratedSample], dt: Double) -> Grid {
        guard dt > 0, samples.count >= 2 else {
            if let only = samples.first {
                return Grid(dt: dt, time: [only.time], x: [only.x], y: [only.y])
            }
            return Grid(dt: dt, time: [], x: [], y: [])
        }
        let t0 = samples[0].time
        let tEnd = samples[samples.count - 1].time
        let span = tEnd - t0
        guard span > 0 else {
            return Grid(dt: dt, time: [t0], x: [samples[0].x], y: [samples[0].y])
        }
        let count = Int((span / dt).rounded(.down)) + 1

        var times = [Double]()
        var xs = [Double]()
        var ys = [Double]()
        times.reserveCapacity(count)
        xs.reserveCapacity(count)
        ys.reserveCapacity(count)

        var idx = 0
        for i in 0..<count {
            let tg = t0 + Double(i) * dt
            // 前進到讓 samples[idx].time ≤ tg < samples[idx+1].time
            while idx + 1 < samples.count && samples[idx + 1].time <= tg {
                idx += 1
            }
            let a = samples[idx]
            let b = idx + 1 < samples.count ? samples[idx + 1] : a
            let denom = b.time - a.time
            let frac = denom > 0 ? (tg - a.time) / denom : 0
            times.append(tg)
            xs.append(a.x + frac * (b.x - a.x))
            ys.append(a.y + frac * (b.y - a.y))
        }
        return Grid(dt: dt, time: times, x: xs, y: ys)
    }
}
