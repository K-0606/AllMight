import Foundation

/// MVP 支援的訓練動作（見 docs/DECISIONS.md D-012）。
///
/// `rawValue` 是存進資料庫與樣本檔的穩定字串，不做在地化；
/// 使用者看到的中文名稱由 App 層對應（見 .claude/rules/ui-text.md）。
public enum Exercise: String, Codable, CaseIterable, Sendable {
    case conventionalDeadlift
    case sumoDeadlift
    case backSquat
    case frontSquat
    case benchPress

    /// 這個動作的第一個相位是否為向心（concentric）。
    ///
    /// 硬舉類從地上把槓往上拉，先向心；蹲舉與臥推先下放（離心）再上推。
    /// 用於 M4 的次數切分判斷動作順序（見 docs/ALGORITHMS.md、docs/FLOW.md 次數切分狀態機）。
    public var startsWithConcentric: Bool {
        switch self {
        case .conventionalDeadlift, .sumoDeadlift:
            return true
        case .backSquat, .frontSquat, .benchPress:
            return false
        }
    }
}
