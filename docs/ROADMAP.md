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
- [x] `VideoSetupView`（動作、重量、槓片直徑；記住上次值）— `VideoSetupModel` 以 UserDefaults 記住上次值並夾範圍；App 測試 4/4
- [x] PhotosPicker 選影片、複製到 Application Support/Videos — 先檢查再複製（通過才留檔）；`FileStore.store` + 測試；不合規顯示 PRD §3.3 錯誤文字
- [x] `VideoInspector`：時長、fps、轉正尺寸、方向、慢動作偵測 + 單元測試 — `swift test` 22/22（含 AVAssetWriter 合成影片橫拍/直拍整合測試）；慢動作的真實相簿影片格式需使用者實機驗證
- [x] `TrimView`：播放器 + 縮圖時間軸 + 起訖把手，限制 1–60 秒 — `TimelineStrip` 把手拖曳＋VoiceOver 微調；`TrimModel` 維持 1–60 秒限制
**驗收**：直拍、橫拍影片都能正確顯示方向；不合規影片顯示 PRD 的錯誤文字。建置通過、`swift test` 23/23、App 測試 6/6。需使用者實機驗證：(a) 真實慢動作影片是否被正確阻擋；(b) 前鏡頭鏡像影片方向（`VideoOrientation` 鏡像分支目前僅內部自洽，未對真實影片確認，M2 FrameReader 接上前勿當成已確認）。

## M2 點選槓片與追蹤
- [x] `PlateSelectView`：顯示起點幀、點擊出圓圈、拖曳與縮放、座標轉 Vision 正規化 — `PlateSelectModel` + `PlateCircleOverlay`；座標數學在 VBTCore（`PlateCoordinates`）附測試；App 測試含 5 筆換算/夾範圍測試
- [x] `FrameReader`（片段範圍、逐幀、時間戳、方向）+ 測試 — 拉取式（非 AsyncThrowingStream，見 D-021）、8-bit 輸出；5 筆測試（幀數、時間戳遞增、片段範圍、直/橫拍方向）
- [x] `PlateTracker`（VNTrackObjectRequest、遺失判斷）— 只用中心點（D-006）；信心/瞬移/框面積缺漏判斷；連續缺漏 > maxGapFrames → trackingLost
- [x] 測試工具：產生合成「移動圓盤」影片（AVAssetWriter）— `SyntheticPlateVideo`（已知軌跡 + ground truth、`rotate90`、`occlusion`、全關鍵影格高位元率）
- [x] 端對端測試：合成影片的追蹤軌跡誤差 < 2 px — 中等速度每幀 < 2 px、平均 < 1.5 px（Vision 底噪 ~0.9px，見 D-023）；直/橫拍一致 < 2 px；遮擋 → trackingLost
**驗收**：合成影片測試通過（`swift test` 45/45、App 測試 14/14）。**需使用者實機驗證**：(a) 2+ 段真實影片點選槓片後追蹤沒跑掉；(b) 前鏡頭鏡像影片方向（D-019 相關，`VideoOrientation` 鏡像分支仍未對真實影片確認）；(c) 真實影片追蹤準確度（模擬器無法判斷，見 OPEN_QUESTIONS Q10）。

## M2.5 追蹤驗證（M3 之前插入，見 DECISIONS D-025）
- [x] `TrackingRunner`（VBTVision actor）：串 `FrameReader → PlateTracker` 產生 `[TrackSample]`，`os.Logger` 記參數/每幀/摘要；跟丟不丟錯而回傳 `lostAtTime`。合成影片測試 2 筆。M4 `AnalysisPipeline` 會重用。
- [x] App 追蹤預覽：`TrackingPreviewModel` + `VideoLayerView`（AVPlayerLayer）+ `TrackingPreviewView`：重播剪好片段、紅點跟槓片、軌跡線、狀態列（樣本數/平均信心/是否跟丟）；「鎖定並追蹤」接進此頁。
**目的**：讓使用者在**真實影片**上目視確認追蹤是否正確，再投入 M3 計算。**需使用者實機驗證**（同 Q10）。

## M3 速度計算（可與 M1/M2 平行）
- [x] `Calibrator`（§1 比例尺、§2 位置）、`GapFiller`（§3 缺漏內插）、`Resampler`（§3 等間隔） — 各附單元測試；`Calibrator` 單位/座標手算例、`GapFiller` 缺漏 =maxGap/+1 邊界、`Resampler` 變動影格率線性精確＋整數倍 span 不掉尾幀
- [x] `SavitzkyGolay`（平滑、一階、二階導數，鏡像邊界，係數最小平方＋快取） — 多項式精確性、線性含邊界、二次內部、含雜訊正弦導數測試
- [x] `KinematicSeries` + `Kinematics.computeSeries`（串 §1–4）；端對端合成訊號測試（ALGORITHMS §8） — MV < 0.02 m/s、ROM < 1 cm，涵蓋 1 下／3 下／30fps／60fps／變動影格率／內部缺漏內插／靜止無動作／空輸入／全缺漏丟 trackingLost
**驗收**：達成。合成**訊號**（σ=2px 高斯）與合成**影片→真實 Vision 追蹤**（`KinematicsVideoTests`）兩路端對端 MV 誤差 < 0.02 m/s、ROM < 1 cm。`swift test` 79/79（VBTCore 47、VBTVision 32）。
**狀態（2026-11-08）**：純 VBTCore，未動 App，未改公式／預設參數 → `analysisVersion` 維持 1。經 `algorithm-reviewer` 審查：修正 `Resampler` 浮點掉尾幀（R1）、補 §8 邊界整合測試（R2/S2）。PV（峰值速度）為雜訊敏感的 `max(v)`，§8 未設界，其準確度與完整 accuracy-check「次數」列待 M4 `RepSegmenter` 後驗。見 DECISIONS D-026。

## M4 次數切分與指標（可與 M1/M2 平行）
- [x] `RepSegmenter`（兩種動作順序）— §5 狀態機；核心去抖後兩端延伸到位置轉折點（見 D-027）；minROM 有效向心；硬舉配後／蹲臥配前離心；尾端無對應向心的離心不算一下。`RepSegmenterTests` 10 筆（§8 邊界全涵蓋）
- [x] `MetricsCalculator`（rep 指標 + 組別摘要 + MPV）— §6 全指標（MV/PV/ROM/MPV、離心、restAfter、相對第 1 下；摘要 repCount/meanVelocity/peakVelocity/meanROM/velocityLoss）。`MetricsCalculatorTests` 6 筆（含 MPV 推進段界定、速度損失、restAfter）
- [x] 邊界測試（ALGORITHMS §8 全部）— 1 下／沒動作／從動作中間開始／最後放下槓鈴／缺漏=maxGapFrames／30fps/60fps/變動影格率，皆次數正確、MV<0.02、ROM<1cm
- [x] `AnalysisPipeline` actor 串起 M2–M4，進度回報、取消 — VBTVision actor，`AsyncThrowingStream<AnalysisProgress>`（tracking→analyzing→finished）；取消經 onTermination→Task 取消→每幀 checkCancellation。`AnalysisPipelineTests` 3 筆（合成影片端對端次數=3、進度遞增、取消<0.5s）
**驗收**：達成。`swift test` 98/98（VBTCore 新增 16、VBTVision 新增 3）、App `xcodebuild test` 14/14。合成 3 下訊號與合成影片端對端次數正確、MV 誤差 <0.02 m/s、ROM <1 cm；取消 <0.5 秒停止。
**狀態（2026-11-09）**：純 VBTCore 新增切分/指標型別與兩計算器；VBTVision 新增 `AnalysisPipeline`（+`TrackingRun.geometry`、`TrackingRunner.onProgress` 加法式變更）。未改公式/預設參數 → `analysisVersion` 維持 1。Q8（minROM 統一 0.10）、scaleMismatch（延 M7）見 DECISIONS D-027。經 `algorithm-reviewer` 審查。真實影片端對端數值待 M5 結果頁接上後、由使用者實機驗證（Q10）。

## M5 分析中、RPE、結果頁
- [x] `AnalysisProgressView`（進度、狀態文字、取消、錯誤導回）— 接 `AnalysisPipeline` stream；`.task` 隨畫面取消；錯誤走 PRD §3.6 文字（追蹤遺失→回點選槓片、沒次數→回剪輯）。`AnalysisModel`（@Observable/@MainActor）
- [x] `RPEPickerSheet`（6/7/7.5/8/8.5/9/9.5/10、熱身、跳過）— `interactiveDismissDisabled` 必選一項，回傳 `(rpe, isWarmup)`
- [x] `ResultView`：播放器（疊槓鈴軌跡線，Q4）、摘要卡、4 格關鍵指標、次數列表（可展開看向心/離心/MPV/ROM/間隔/相對第1下）、Swift Charts 速度曲線（拖曳讀值）— `ResultModel`/`VelocityChart`/`RepList`
- [x] 指標說明（ⓘ）文字 — `MetricInfo`（ROM/峰值/MV/速度損失/MPV）+ `MetricInfoSheet`
- [x] 共用元件 `PrimaryButton`/`Card`/`MetricTile`/`RepRow`、`Formatters` 結果頁格式、`PreviewData`
**驗收**：達成（自動化範圍）。導覽接點：點選槓片 → 追蹤驗證頁「開始分析」→ 分析中 → RPE → 結果頁；RPE 在結果之前；M5 不持久化（儲存為 M6）。`BuildProject` 成功、`swift test` 99/99（VBTKit 未動）、App `xcodebuild test` 19/19（iPhone 17，新增 `FormattersTests` 5）。經 ios-reviewer 審查並修正（RPE sheet 滑掉卡死、速度曲線 VoiceOver 文字替代、摘要 Text 插值、Formatters 固定小數點）。**需使用者實機/模擬器驗證**：(a) 用合成影片從頭走到結果頁、數字格式與軌跡線正確；(b) VoiceOver 實地讀出每一下速度與摘要。
**狀態（2026-11-09）**：純 App 層，未動 VBTKit → `analysisVersion` 維持 1。Q4（結果頁畫軌跡線）已回答並移入 DECISIONS D-028。速度曲線「逐下標示範圍」因 `SetAnalysis.reps` 不含相位時間而延後（見 D-028、OPEN_QUESTIONS Q11）。

## M6 儲存與歷史
- [ ] 分析完成自動存 `WorkoutSet` + 樣本檔
- [ ] `HistoryView`（依日期分組、左滑刪除、刪除連同檔案）
- [ ] 編輯重量/RPE；用存好的樣本重算（不重新追蹤）
- [ ] `analysisVersion` 升級時自動重算
**驗收**：重開 App 資料還在；刪除後檔案確實消失（測試檢查檔案系統）。

## M7 打磨與真實影片驗證
- [ ] `FilmingTipsView`
- [ ] 效能：30 秒 60fps 影片分析時間量測（實機），目標 ≤ 15 秒
- [ ] 用使用者提供的測試影片集調整參數，記錄在 DECISIONS（含：真實影片黏滯點是否讓 `RepSegmenter` 把一下切成兩下——目前已驗單調上升的下陷不會被切，真正位置反轉才切；需實片確認；以及 scaleMismatch 警告、各動作 minROM，見 D-027）
- [ ] 圈選大小影響追蹤穩定度與校正（2026-11-10 實機觀察，見 DECISIONS D-029）：圈越大→追蹤框越大→框入背景/架子/槓桿強邊緣→框中心每幀漂移→追蹤驗證頁軌跡線左右抖；圈又兼作比例尺(`scale = plateCm/diameterPx`)，圈比槓片大會讓速度/ROM 整體低估。待做：(a) 把 D-027 的 scaleMismatch 警告落地，當 Vision 追蹤框大小與使用者圈差太多時提示重畫；(b) 追蹤驗證頁軌跡線顯示時加平滑（純視覺，不影響計算）；(c) 點選槓片頁加強「貼齊外緣」引導/預設圈更貼。水平抖動本身不進數值（速度/ROM 只用垂直位置），主要影響觀感與（圈過大時的）校正。
- [ ] 錯誤與空狀態全部走過一次
**驗收**：PRD §1 成功標準達成，或列出差距與原因。

---

## 後續版本（MVP 之後，未經同意不要實作）
- V1.1 骨架與關節角度（VNDetectHumanBodyPoseRequest）
- V1.2 疊圖重播、拖曳逐幀、縮放、匯出影片
- V1.3 即時相機模式 + 語音播報
- V1.4 1RM / LVP、進步趨勢、歷史比較
- V1.5 iCloud 同步、英文介面、lb 單位
