---
paths:
  - "**/*.swift"
---

# Swift 程式風格

- Swift 6 語言模式，嚴格並行檢查。不要用 `@unchecked Sendable`、`nonisolated(unsafe)` 來消警告；真的需要時加註解說明為什麼安全，並在回報中提出。
- 只對 Apple 舊 API 用 `@preconcurrency import`（例如 AVFoundation），並註明原因。
- 值型別優先（`struct`、`enum`）；跨 actor 傳遞的型別必須 `Sendable`。
- 禁止強制解包 `!` 與 `try!`，測試程式除外。用 `guard` 提早返回並丟出具體錯誤。
- 不用 `print` 除錯後留在程式裡；需要記錄用 `os.Logger`（subsystem = Bundle ID，category = 模組名）。
- 命名：型別 UpperCamelCase，其他 lowerCamelCase；單位寫進名字（`durationSeconds`、`velocityMetersPerSecond`）或用註解標明。內部一律 SI 單位。
- 公開 API（package 的 `public`）要有 `///` 文件註解，說明單位與座標系。
- 一個檔案一個主要型別，檔名同型別名。
- 魔術數字放進 `AnalysisParameters` 或具名常數。
- 不留被註解掉的程式碼與 TODO（TODO 改寫進 ROADMAP 或 OPEN_QUESTIONS）。
