import Foundation

/// Savitzky-Golay 平滑與微分（docs/ALGORITHMS.md §4、skill velocity-analysis §2）。
///
/// 對**等間隔**取樣（間隔 `dt` 秒）的序列，用一個滑動多項式視窗同時求：
/// 平滑位置、一階導數（速度，m/s）與二階導數（加速度，m/s²）。
/// 視窗半徑 `halfWindow`（全長 `2h+1`）、多項式階數 `order`。
/// 邊界用**鏡像延伸** `x[−i] = 2·x[0] − x[i]`（保持斜率連續）。
///
/// 係數以最小平方 `(AᵀA)⁻¹Aᵀ` 一次解好並快取於實例內：對視窗 `m = −h…h` 建
/// Vandermonde `A[m][k] = mᵏ`，平滑取 `(AᵀA)⁻¹Aᵀ` 第 0 列、一階取第 1 列、二階取第 2 列×2。
/// 純 Swift、小矩陣用高斯消去法求逆，不需 LAPACK。
public struct SavitzkyGolay: Sendable {
    /// 視窗半徑；視窗全長為 `2·halfWindow + 1`。
    public let halfWindow: Int
    /// 多項式階數。
    public let order: Int

    // 卷積核（長度 2h+1），由多項式係數列建成。對視窗值做點積即得中心點結果。
    private let smoothKernel: [Double]   // (AᵀA)⁻¹Aᵀ 第 0 列
    private let firstKernel: [Double]    // 第 1 列（除以 dt 得 m/s）
    private let secondKernel: [Double]   // 第 2 列 × 2（除以 dt² 得 m/s²）

    /// 由視窗長度（秒）與影格率決定半徑（ALGORITHMS §4）。
    /// `N = 奇數(round(windowSeconds × fps))`，最少 5；回傳 `h = (N−1)/2`。
    public static func halfWindow(windowSeconds: Double, fps: Double) -> Int {
        var n = Int((windowSeconds * fps).rounded())
        if n < 5 { n = 5 }
        if n % 2 == 0 { n += 1 }
        return (n - 1) / 2
    }

    /// 建立係數。要求 `halfWindow ≥ 1`、`order ≥ 1`，且視窗長度 `2h+1 > order`。
    public init(halfWindow: Int, order: Int) {
        let h = max(1, halfWindow)
        // 視窗點數必須多於多項式係數個數，否則最小平方欠定。
        let ord = min(max(1, order), 2 * h)
        self.halfWindow = h
        self.order = ord

        let dim = ord + 1
        // 冪次和 S[p] = Σ_{m=-h..h} mᵖ，建 AᵀA：B[i][j] = S[i+j]。
        var powerSums = [Double](repeating: 0, count: 2 * ord + 1)
        for m in -h...h {
            let md = Double(m)
            var p = 1.0
            for q in 0..<(2 * ord + 1) {
                powerSums[q] += p
                p *= md
            }
        }
        var b = [[Double]](repeating: [Double](repeating: 0, count: dim), count: dim)
        for i in 0..<dim {
            for j in 0..<dim {
                b[i][j] = powerSums[i + j]
            }
        }
        let invB = SavitzkyGolay.invert(b) ?? SavitzkyGolay.identity(dim)

        // kernel_row[r] = Σ_k invB[row][k] · mᵏ，m = r − h。
        func kernel(row: Int) -> [Double] {
            guard row < dim else { return [Double](repeating: 0, count: 2 * h + 1) }
            var out = [Double](repeating: 0, count: 2 * h + 1)
            for r in 0...(2 * h) {
                let md = Double(r - h)
                var p = 1.0
                var acc = 0.0
                for k in 0..<dim {
                    acc += invB[row][k] * p
                    p *= md
                }
                out[r] = acc
            }
            return out
        }
        self.smoothKernel = kernel(row: 0)
        self.firstKernel = kernel(row: 1)
        let secondRaw = kernel(row: 2)
        self.secondKernel = secondRaw.map { 2 * $0 }
    }

    /// 平滑位置（與輸入同長度、同單位）。
    public func smooth(_ x: [Double]) -> [Double] {
        convolve(x, smoothKernel)
    }

    /// 一階導數。`dt` 為取樣間隔（秒）；輸入為公尺時回傳 m/s。
    public func firstDerivative(_ x: [Double], dt: Double) -> [Double] {
        guard dt > 0 else { return [Double](repeating: 0, count: x.count) }
        return convolve(x, firstKernel).map { $0 / dt }
    }

    /// 二階導數。`dt` 為取樣間隔（秒）；輸入為公尺時回傳 m/s²。
    public func secondDerivative(_ x: [Double], dt: Double) -> [Double] {
        guard dt > 0 else { return [Double](repeating: 0, count: x.count) }
        let dt2 = dt * dt
        return convolve(x, secondKernel).map { $0 / dt2 }
    }

    // MARK: - 私有

    /// 以鏡像邊界對每個索引做視窗點積。
    private func convolve(_ x: [Double], _ kernel: [Double]) -> [Double] {
        let n = x.count
        guard n > 0 else { return [] }
        let h = halfWindow
        var out = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var acc = 0.0
            for t in -h...h {
                acc += kernel[t + h] * SavitzkyGolay.mirrored(x, i + t)
            }
            out[i] = acc
        }
        return out
    }

    /// 鏡像延伸索引：`x[−i] = 2x[0] − x[i]`、右側對稱；超出再鏡一次則夾到端點。
    private static func mirrored(_ x: [Double], _ idx: Int) -> Double {
        let n = x.count
        if idx < 0 {
            let r = -idx
            return r < n ? 2 * x[0] - x[r] : x[0]
        }
        if idx >= n {
            let r = 2 * (n - 1) - idx
            return r >= 0 ? 2 * x[n - 1] - x[r] : x[n - 1]
        }
        return x[idx]
    }

    /// 以高斯消去法求反矩陣（小方陣）；奇異時回傳 nil。
    private static func invert(_ a: [[Double]]) -> [[Double]]? {
        let n = a.count
        var m = a
        var inv = identity(n)
        for col in 0..<n {
            var pivotRow = col
            var maxv = abs(m[col][col])
            for r in (col + 1)..<n where abs(m[r][col]) > maxv {
                maxv = abs(m[r][col])
                pivotRow = r
            }
            if maxv < 1e-15 { return nil }
            if pivotRow != col {
                m.swapAt(col, pivotRow)
                inv.swapAt(col, pivotRow)
            }
            let pivot = m[col][col]
            for j in 0..<n {
                m[col][j] /= pivot
                inv[col][j] /= pivot
            }
            for r in 0..<n where r != col {
                let factor = m[r][col]
                if factor != 0 {
                    for j in 0..<n {
                        m[r][j] -= factor * m[col][j]
                        inv[r][j] -= factor * inv[col][j]
                    }
                }
            }
        }
        return inv
    }

    private static func identity(_ n: Int) -> [[Double]] {
        var out = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for i in 0..<n { out[i][i] = 1 }
        return out
    }
}
