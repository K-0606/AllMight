import Foundation

/// 缺漏內插（docs/ALGORITHMS.md §3 步驟 1–2）。純函式。
///
/// 信心 < `minConfidence` 的樣本視為缺漏。對每一段連續缺漏：
/// - 兩側都有有效樣本：長度 ≤ `maxGapFrames` → 依時間戳線性內插；超過 → 丟 `trackingLost`。
/// - 落在開頭或結尾（只有單側或無側可依）：無法內插，長度 ≤ `maxGapFrames` → 丟棄這幾點；
///   超過 → 丟 `trackingLost`。開頭/結尾本來就少數幾幀，丟棄只是讓等間隔網格晚一點開始／早一點結束。
///
/// 內插後的樣本信心設為 `minConfidence`（視為剛好通過門檻的有效點）。
public enum GapFiller {
    public static func fill(
        _ samples: [CalibratedSample],
        minConfidence: Double,
        maxGapFrames: Int
    ) throws -> [CalibratedSample] {
        let n = samples.count
        guard n > 0 else { return [] }

        func isValid(_ s: CalibratedSample) -> Bool { Double(s.confidence) >= minConfidence }

        var result = samples
        var dropIndices = Set<Int>()
        var i = 0
        while i < n {
            if isValid(result[i]) {
                i += 1
                continue
            }
            // 找出這一段連續缺漏 [i, j]
            var j = i
            while j + 1 < n && !isValid(result[j + 1]) { j += 1 }
            let runLength = j - i + 1
            let hasPrev = i - 1 >= 0
            let hasNext = j + 1 < n

            if hasPrev && hasNext {
                if runLength > maxGapFrames {
                    throw AnalysisError.trackingLost(atTime: result[i].time)
                }
                let a = result[i - 1]
                let b = result[j + 1]
                let span = b.time - a.time
                for k in i...j {
                    let frac = span > 0 ? (result[k].time - a.time) / span : 0
                    result[k].x = a.x + frac * (b.x - a.x)
                    result[k].y = a.y + frac * (b.y - a.y)
                    result[k].confidence = Float(minConfidence)
                }
            } else {
                if runLength > maxGapFrames {
                    throw AnalysisError.trackingLost(atTime: result[i].time)
                }
                for k in i...j { dropIndices.insert(k) }
            }
            i = j + 1
        }

        if dropIndices.isEmpty { return result }
        return result.enumerated().filter { !dropIndices.contains($0.offset) }.map { $0.element }
    }
}
