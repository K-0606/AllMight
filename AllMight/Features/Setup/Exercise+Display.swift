import SwiftUI
import VBTCore

/// 動作的繁體中文顯示名稱（App 層；VBTCore 不含在地化字串，見 ui-text 規則）。
extension Exercise {
    var displayName: LocalizedStringKey {
        switch self {
        case .conventionalDeadlift: "傳統硬舉"
        case .sumoDeadlift: "相撲硬舉"
        case .backSquat: "背蹲舉"
        case .frontSquat: "前蹲舉"
        case .benchPress: "臥推"
        }
    }
}
