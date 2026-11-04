---
name: swiftui-screens
description: Visual style, design tokens and reusable components for AllMight's SwiftUI screens (dark theme, metric tiles, rep bars, velocity chart with Swift Charts, trim timeline, plate circle overlay). Use when building or changing any screen in the app target.
---

# 畫面與設計系統

## 1. 風格
- 深色介面為主（App 強制 `.preferredColorScheme(.dark)`，MVP 不做淺色）。黑底、深灰卡片、薄荷綠強調色，數字大而清楚。參考 Arcus 的資訊密度，但不要複製它的圖示、字樣或版面細節。
- 圖示一律用 SF Symbols。

## 2. Token（`DesignSystem/Theme.swift`）
```swift
enum Theme {
    enum Color {
        static let background = SwiftUI.Color(red: 0.04, green: 0.05, blue: 0.05)
        static let surface    = SwiftUI.Color(red: 0.10, green: 0.11, blue: 0.11)
        static let surfaceHi  = SwiftUI.Color(red: 0.15, green: 0.16, blue: 0.16)
        static let textPrimary   = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color.white.opacity(0.6)
        static let accent  = SwiftUI.Color(red: 0.24, green: 0.88, blue: 0.62)   // 主要按鈕、長條、曲線
        static let warning = SwiftUI.Color(red: 1.00, green: 0.72, blue: 0.26)   // 速度下降、警告
        static let danger  = SwiftUI.Color(red: 1.00, green: 0.40, blue: 0.40)
    }
    enum Space { static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24 }
    enum Radius { static let card: CGFloat = 16, button: CGFloat = 14 }
    enum Font {
        static let metricLarge = SwiftUI.Font.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit()
        static let metric      = SwiftUI.Font.system(.title3, design: .rounded).weight(.semibold).monospacedDigit()
        static let label       = SwiftUI.Font.caption
    }
}
```
數值可以調，但所有畫面只能引用 token。

## 3. 共用元件（`DesignSystem/Components/`）
| 元件 | 用途 |
|---|---|
| `PrimaryButton` | 滿版薄荷綠按鈕（「選擇影片」「鎖定並追蹤」） |
| `Card` | 深灰圓角容器，標題列可帶 SF Symbol 與 ⓘ 按鈕 |
| `MetricTile` | 數值 + 單位 + 標籤，4 格一排（關鍵指標） |
| `RepRow` | 「REP n」+ 長條（寬度依 MV / 本組最大 MV）+ 數值 + 相對第 1 下的變化；可展開 |
| `SettingRow` | 影片設定頁的一列（圖示、標題、值、chevron） |

## 4. 特殊畫面做法
- **剪輯時間軸**：`HStack` 排縮圖，上面疊兩個可拖曳把手（`DragGesture`），中間區域亮、兩側變暗；把手位置 ↔ 時間用同一個換算函式並寫測試。
- **點選槓片**：起點幀 `Image` 用 `.aspectRatio(contentMode: .fit)`，用 `GeometryReader` 算出 `imageRect`。圓圈 `Circle().stroke(Theme.Color.accent, lineWidth: 3)`，支援 `DragGesture` 移動、`MagnifyGesture` 縮放（直徑限制在影像寬的 5%–60%）。座標轉換見 skill `plate-tracking`。
- **速度曲線**：Swift Charts `AreaMark` + `LineMark`（x = 時間 s，y = 速度 m/s），每一下用 `RectangleMark` 淡色背景標範圍並標 R1、R2…；`chartXSelection` 拖曳顯示當下數值。
- **影片播放**：`VideoPlayer(player:)`，播放範圍限制在片段內（`AVPlayerItem.forwardPlaybackEndTime`，起點 seek）。

## 5. 每個畫面完成時檢查
- `#Preview` 使用 `PreviewData` 的假 `SetAnalysis`（3 下、MV 0.28/0.25/0.24）
- 動態字體放到最大時不被截斷（可換行或捲動）
- VoiceOver 讀得出主要數值
