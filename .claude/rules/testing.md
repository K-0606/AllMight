# 測試規則（永遠套用）

- 使用 **Swift Testing**（`import Testing`、`@Test`、`#expect`、`#require`）。UI 流程測試才用 XCTest/XCUITest。
- 浮點數比較用容差：`#expect(abs(actual - expected) < tol)`，容差依 `docs/ALGORITHMS.md §8`。
- 合成資料用固定亂數種子，結果可重現。
- 測試命名描述行為：`@Test("三下半正弦訊號判斷出 3 次")`。
- 演算法：先寫測試再實作。修 bug：先寫重現 bug 的測試。
- 測試影片：合成影片在測試執行時產生到暫存資料夾；使用者提供的真實影片放 `TestVideos/`（已列入 .gitignore），測試找不到檔案時跳過（`.enabled(if:)`），不能失敗。
- 每次回報前必跑：`swift test --package-path Packages/VBTKit`；動到 App 層再跑 `xcodebuild ... test`。
