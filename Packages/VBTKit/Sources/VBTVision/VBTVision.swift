import Foundation
import VBTCore

/// `VBTVision` 模組的佔位命名空間，用來確認可依賴 `VBTCore` 並建置。
///
/// 影片檢查、逐幀解碼、方向處理與 Vision 槓片追蹤（`VideoInspector`、`FrameReader`、
/// `PlateTracker`、`AnalysisPipeline`）在 M1／M2 加入（見 `docs/ARCHITECTURE.md`）。
public enum VBTVision {
    /// 透過 `VBTCore` 讀到的演算法版本，驗證模組依賴方向 `VBTVision → VBTCore`。
    public static let coreAnalysisVersion = VBTCore.analysisVersion
}
