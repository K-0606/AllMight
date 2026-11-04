import Foundation

/// `VBTCore` 模組的佔位命名空間，用來確認 package 能在 macOS 上建置與 `swift test`。
///
/// 真正的計算型別（`Calibrator`、`Resampler`、`SavitzkyGolay`、`RepSegmenter`、
/// `MetricsCalculator` 等）在 M3／M4 加入，定義與公式以 `docs/ALGORITHMS.md` 為準。
public enum VBTCore {
    /// 演算法版本。改任何公式或預設參數時 +1（見 `docs/ALGORITHMS.md`）。
    public static let analysisVersion = 1
}
