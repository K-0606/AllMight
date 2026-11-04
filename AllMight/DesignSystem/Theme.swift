import SwiftUI

/// 設計 token：色彩、間距、圓角、字體。所有畫面只引用這裡的值，不寫死顏色或尺寸。
/// 風格見 skill `swiftui-screens`（深色介面為主）。
enum Theme {
    enum Color {
        static let background = SwiftUI.Color(red: 0.04, green: 0.05, blue: 0.05)
        static let surface    = SwiftUI.Color(red: 0.10, green: 0.11, blue: 0.11)
        static let surfaceHi  = SwiftUI.Color(red: 0.15, green: 0.16, blue: 0.16)
        static let textPrimary   = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color.white.opacity(0.6)
        /// 主要按鈕、長條、曲線的薄荷綠強調色。
        static let accent  = SwiftUI.Color(red: 0.24, green: 0.88, blue: 0.62)
        /// 速度下降、警告。
        static let warning = SwiftUI.Color(red: 1.00, green: 0.72, blue: 0.26)
        static let danger  = SwiftUI.Color(red: 1.00, green: 0.40, blue: 0.40)
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 14
    }

    enum Font {
        static let metricLarge = SwiftUI.Font.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit()
        static let metric      = SwiftUI.Font.system(.title3, design: .rounded).weight(.semibold).monospacedDigit()
        static let label       = SwiftUI.Font.caption
    }
}
