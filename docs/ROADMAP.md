# Roadmap 與里程碑

狀態：`[ ]` 未開始　`[~]` 進行中　`[x]` 完成。Agent 完成一項就勾選，並在項目後註明驗證方式。

每個里程碑的**完成定義**：
- `swift test --package-path Packages/VBTKit` 全部通過
- `xcodebuild ... build` 與 `test` 通過，沒有新的警告
- 驗收項目都有對應的測試，或寫明「需使用者實機驗證」
- 相關文件已更新

---

## M0 專案骨架　（使用者先在 Xcode 建專案，見 README_開始使用.md）
- [x] 建立 `Packages/VBTKit`（VBTCore、VBTVision、兩個測試 target），platforms iOS 17 / macOS 14，Swift 6 — `swift test` 通過（2 佔位測試）
- [x] App 加入本機 package 依賴 — 使用者在 Xcode 以 Add Local 加入 `Packages/VBTKit`，VBTCore／VBTVision 已連結到 AllMight target
- [x] `HomeView`：TabView（訓練 / 歷史），兩個空狀態畫面 — 模擬器建置通過
- [x] `DesignSystem/Theme.swift`：色彩、字體、間距（見 skill `swiftui-screens`）
- [x] SwiftData `ModelContainer` 設定、`WorkoutSet` 模型、`FileStore`
- [x] 一個佔位測試在 package 與 App 都能跑 — 兩邊皆綠（package 2/2、App `AllMightTests` 1/1）
**驗收**：模擬器能開啟 App 並切換分頁；兩種測試指令都通過。✅ 達成。
**狀態（2026-11-04）**：Bundle ID `com.kun0606.AllMight`、最低部署 iOS 17.6、Swift Language Version 6（專案與兩個 target）。`swift test` 2/2；`xcodebuild … test`（iPhone 17）`** TEST SUCCEEDED **`（App 1/1）。Swift 6 嚴格並行檢查促使 `FileStore` 改為 `nonisolated` 無狀態型別（見 DECISIONS D-011）。M0 完成。

## M1 影片設定、匯入與剪輯
- [ ] `VideoSetupView`（動作、重量、槓片直徑；記住上次值）
- [ ] PhotosPicker 選影片、複製到 Application Support/Videos
- [ ] `VideoInspector`：時長、fps、轉正尺寸、方向、慢動作偵測 + 單元測試
- [ ] `TrimView`：播放器 + 縮圖時間軸 + 起訖把手，限制 1–60 秒
**驗收**：直拍、橫拍影片都能正確顯示方向；不合規影片顯示 PRD 的錯誤文字。

## M2 點選槓片與追蹤
- [ ] `PlateSelectView`：顯示起點幀、點擊出圓圈、拖曳與縮放、座標轉 Vision 正規化
- [ ] `FrameReader`（片段範圍、逐幀、時間戳、方向）+ 測試
- [ ] `PlateTracker`（VNTrackObjectRequest、遺失判斷）
- [ ] 測試工具：產生合成「移動圓盤」影片（AVAssetWriter）
- [ ] 端對端測試：合成影片的追蹤軌跡誤差 < 2 px
**驗收**：合成影片測試通過；使用者用 2 段真實影片實機確認追蹤沒跑掉（需使用者驗證）。

## M3 速度計算（可與 M1/M2 平行）
- [ ] `Calibrator`、缺漏內插、`Resampler`
- [ ] `SavitzkyGolay`（平滑、一階、二階導數，鏡像邊界）
- [ ] 合成訊號測試（ALGORITHMS §8）
**驗收**：已知速度函數的誤差 < 0.02 m/s。

## M4 次數切分與指標（可與 M1/M2 平行）
- [ ] `RepSegmenter`（兩種動作順序）
- [ ] `MetricsCalculator`（rep 指標 + 組別摘要 + MPV）
- [ ] 邊界測試（ALGORITHMS §8 全部）
- [ ] `AnalysisPipeline` actor 串起 M2–M4，進度回報、取消
**驗收**：合成 3 下訊號次數正確、MV/ROM 誤差在範圍內；取消可在 0.5 秒內停止。

## M5 分析中、RPE、結果頁
- [ ] `AnalysisProgressView`（進度、狀態文字、取消、錯誤導回）
- [ ] `RPEPickerSheet`
- [ ] `ResultView`：播放器、摘要、4 格關鍵指標、次數列表（可展開）、速度曲線
- [ ] 指標說明（ⓘ）文字
**驗收**：用合成影片從頭走到結果頁；數字格式符合 PRD；VoiceOver 可讀出每一下速度。

## M6 儲存與歷史
- [ ] 分析完成自動存 `WorkoutSet` + 樣本檔
- [ ] `HistoryView`（依日期分組、左滑刪除、刪除連同檔案）
- [ ] 編輯重量/RPE；用存好的樣本重算（不重新追蹤）
- [ ] `analysisVersion` 升級時自動重算
**驗收**：重開 App 資料還在；刪除後檔案確實消失（測試檢查檔案系統）。

## M7 打磨與真實影片驗證
- [ ] `FilmingTipsView`
- [ ] 效能：30 秒 60fps 影片分析時間量測（實機），目標 ≤ 15 秒
- [ ] 用使用者提供的測試影片集調整參數，記錄在 DECISIONS
- [ ] 錯誤與空狀態全部走過一次
**驗收**：PRD §1 成功標準達成，或列出差距與原因。

---

## 後續版本（MVP 之後，未經同意不要實作）
- V1.1 骨架與關節角度（VNDetectHumanBodyPoseRequest）
- V1.2 疊圖重播、拖曳逐幀、縮放、匯出影片
- V1.3 即時相機模式 + 語音播報
- V1.4 1RM / LVP、進步趨勢、歷史比較
- V1.5 iCloud 同步、英文介面、lb 單位
