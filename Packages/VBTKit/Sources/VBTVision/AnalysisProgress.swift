import Foundation
import VBTCore

/// 分析管線對外回報的進度（見 docs/ARCHITECTURE.md §3、§5）。值型別，可跨 actor 傳遞。
public enum AnalysisProgress: Sendable, Equatable {
    /// 追蹤中；`fraction` 為估計進度（0…1）。
    case tracking(fraction: Double)
    /// 追蹤完成，進行 VBTCore 運動學與指標計算。
    case analyzing
    /// 完成，附帶分析結果與原始追蹤樣本（樣本供 App 層存檔，之後升級重算時不用重新追蹤，見 DECISIONS D-007、D-030）。
    case finished(SetAnalysis, samples: [TrackSample])
}
