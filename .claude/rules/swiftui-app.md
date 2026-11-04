---
paths:
  - "AllMight/**/*.swift"
---

# App 層（SwiftUI）規則

- 狀態：`@Observable` + `@MainActor` 的 Model 類別；View 用 `@State` 持有、`@Bindable` 綁定。不要用 `ObservableObject` / `@Published`。
- View 不做運算或 I/O；交給 Model，重運算交給 `AnalysisPipeline` actor。
- 導覽：每個分頁一個 `NavigationStack(path:)`，路由 `enum Route: Hashable`。sheet 用 `.sheet(item:)`。
- 色彩、字體、間距只能用 `DesignSystem/Theme.swift` 的 token，不寫死顏色值。
- 數字一律用等寬數字（`.monospacedDigit()`），格式化集中在 `Formatters.swift`（速度 2 位小數、cm 1 位、% 1 位、秒 2 位）。
- 每個 View 檔附 `#Preview`，使用假資料（`PreviewData.swift`）。
- 無障礙：互動元件要有 `accessibilityLabel`；圖表提供 `accessibilityChartDescriptor` 或文字替代。
- SwiftData：`@Query` 只在 View 用；寫入透過 `ModelContext`，刪除時呼叫 `FileStore` 一併刪檔。
- 新增檔案放在對應的 `Features/<功能>/` 資料夾（專案使用 Xcode 同步資料夾，新檔會自動加入 target；若沒自動加入，告知使用者）。
