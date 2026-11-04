# 設計決策紀錄

格式：`## D-編號 標題` → 日期、狀態（已決定 / 暫定）、決定、原因、替代方案。新的放最下面，不要改舊的；推翻時新增一筆並註明取代哪一筆。

## D-001 MVP 只做影片匯入分析
- 2026-11-03 · 已決定（使用者）
- 骨架、疊圖重播、即時相機、1RM 延後。

## D-002 只用 Apple 原生框架，iOS 17+
- 2026-11-03 · 已決定（使用者）
- 先純原生，有需要再討論加第三方。原因：減少依賴、Vision 已有物件追蹤。

## D-003 繁中介面、純本機儲存
- 2026-11-03 · 已決定（使用者）

## D-004 開發環境：Mac + Xcode + Claude Code
- 2026-11-03 · 已決定（使用者）

## D-005 邏輯放本機 Swift Package（VBTKit）
- 2026-11-03 · 暫定
- 原因：`swift test` 在 Mac 上直接跑，Agent 驗證演算法快；強制分層。
- 替代：全部放 App target（測試要開模擬器，較慢）。

## D-006 比例尺用使用者調整的圓圈，不用追蹤框大小
- 2026-11-03 · 暫定
- 原因：VNTrackObjectRequest 的框大小會漂移；使用者對齊一次最穩。追蹤框只用來做 25% 差異警告。
- 替代：VNDetectContoursRequest 自動貼齊圓形（之後可加）。

## D-007 保存原始 TrackSample，改參數不用重新追蹤
- 2026-11-03 · 暫定
- 原因：追蹤是最慢的一步；演算法會一直調。

## D-008 平滑用 Savitzky-Golay，先重新取樣成等間隔
- 2026-11-03 · 暫定
- 原因：保留峰值形狀，比移動平均好；手機影片可能是變動影格率。

## D-009 正式名稱 AllMight、Bundle ID com.k0606.AllMight（取代工作名稱 LiftVelo）
- 2026-11-04 · 已決定（使用者）
- 決定：App 正式名稱為 **AllMight**，Bundle ID `com.kun0606.AllMight`（Personal Team 需全域唯一，原 `com.k0606.AllMight` 已被占用故改此），開發團隊為使用者的 Personal Team。所有文件、scheme、資料夾一律改用 AllMight，不再出現 LiftVelo。
- 原因：Xcode 專案已以 AllMight 建立，沿用最省事。回答了 OPEN_QUESTIONS Q1。

## D-010 文件與 package 放專案根目錄，App 原始碼放同步資料夾
- 2026-11-04 · 已決定（使用者）
- 決定：`docs/`、`.claude/`、`CLAUDE.md`、`.gitignore`、藍圖、`Packages/VBTKit/` 放在專案根目錄 `/Users/kun/AllMight/`（與 `AllMight.xcodeproj` 同層）；App 原始碼放同步資料夾 `AllMight/`（`PBXFileSystemSynchronizedRootGroup`）。
- 原因：專案用 Xcode 16 同步資料夾群組，資料夾裡的所有檔案都會被收進 App target；把文件與 package 放在同步資料夾外，避免 `.md`／`.json`／參考影片被打包進 App，也讓 `swift test --package-path Packages/VBTKit` 等相對路徑從根目錄直接對上。
- 替代：文件留在同步資料夾內（會被誤收進 target）。

## D-011 FileStore 設為 nonisolated、無儲存狀態
- 2026-11-04 · 暫定
- 決定：App target 預設 actor 隔離為 MainActor（`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`）；`FileStore` 標記 `nonisolated`、不持有 `FileManager`，方法內直接用 `FileManager.default`。
- 原因：Swift 6 嚴格並行下，若 `FileStore` 繼承 MainActor 隔離，背景 `AnalysisPipeline` 存影片／樣本檔時會違規。檔案 I/O 需能從任何 context 呼叫；`FileManager.default` 對這些操作執行緒安全，去掉儲存屬性也讓型別自然 `Sendable`。
- 替代：保留可注入的 `FileManager`（為測試）—— 但會讓 `nonisolated Sendable` 型別含非 Sendable 屬性而編譯失敗，暫不需要。
