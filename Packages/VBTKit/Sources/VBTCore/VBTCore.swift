import Foundation

/// `VBTCore` 模組的佔位命名空間，用來確認 package 能在 macOS 上建置與 `swift test`。
///
/// 真正的計算型別（`Calibrator`、`Resampler`、`SavitzkyGolay`、`RepSegmenter`、
/// `MetricsCalculator` 等）在 M3／M4 加入，定義與公式以 `docs/ALGORITHMS.md` 為準。
public enum VBTCore {
    /// 演算法版本。改任何公式或預設參數時 +1（見 `docs/ALGORITHMS.md`）。
    /// v2（M7）：`PhaseMetrics` 新增相位起訖時間（供速度曲線標示每一下範圍，Q11）。純加法、數值不變；
    /// 升版僅為讓 M6 舊紀錄經升級重算補上新欄位（舊欄位為 optional，解碼不受影響）。
    public static let analysisVersion = 2
}
