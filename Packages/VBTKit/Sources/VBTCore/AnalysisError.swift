import Foundation

/// 分析管線各階段可能回傳的錯誤（見 docs/ARCHITECTURE.md §6）。
///
/// 放在 VBTCore，讓 VBTVision 與 App 層共用；App 層負責對應成 PRD 的使用者文字。
/// 時間單位為秒，相對片段起點。
public enum AnalysisError: Error, Sendable, Equatable {
    /// 影片無法讀取（沒有影像軌道、解碼失敗等）。
    case videoUnreadable
    /// 慢動作影片（含時間變速或影格率過高），MVP 不支援（見 D-013）。
    case unsupportedSlowMotion
    /// 影格率低於可分析門檻；關聯值為實際 fps。
    case frameRateTooLow(Double)
    /// 影片長度低於下限；關聯值為實際長度（秒）。
    case videoTooShort(seconds: Double)
    /// 影片長度超過上限；關聯值為實際長度（秒）。
    case videoTooLong(seconds: Double)
    /// 追蹤在某時間點跟丟槓片；關聯值為該時間（秒）。
    case trackingLost(atTime: Double)
    /// 片段裡偵測不到任何一下完整動作。
    case noRepsDetected
    /// 工作被取消。
    case cancelled
}
