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

## D-012 MVP 動作清單：5 項（回答 Q2）
- 2026-11-05 · 已決定（使用者）
- 決定：MVP 支援 5 個動作：傳統硬舉（conventionalDeadlift）、相撲硬舉（sumoDeadlift）、背蹲舉（backSquat）、前蹲舉（frontSquat）、臥推（benchPress）。與 ARCHITECTURE §2 現有 `Exercise` enum 一致。硬舉類 `startsWithConcentric = true`，蹲舉與臥推為 `false`（影響 M4 次數切分的動作順序）。
- 原因：涵蓋最常用 VBT 的主要動作；之後要加（過頭推舉、划船等）再討論。

## D-013 慢動作影片：阻擋並說明（回答 Q3）
- 2026-11-05 · 已決定（使用者）
- 決定：`VideoInspector` 偵測到慢動作（fps > 120，或 asset 的 segments 有時間變速、`timeMapping.source.duration != target.duration`）即回傳 `AnalysisError.unsupportedSlowMotion`，App 層顯示「請先在照片 App 中把慢動作改成一般速度，或匯出後再選」。MVP 不做自動換算。
- 原因：最簡單、速度最準；慢動作檔格式隨 iOS 版本不同，換算需真實影片實機驗證，列入後續版本。
- 替代：自動依 timeMapping 還原真實時間軸（後續版本再評估）。

## D-014 重量單位：只支援 kg（回答 Q9）
- 2026-11-05 · 已決定（使用者）
- 決定：MVP 重量欄位只用 kg，0.5 kg 一格、範圍 1–500。lb 列入後續版本 V1.5。
- 原因：減少設定與顯示複雜度；目標使用者多用公制。

## D-015 AnalysisError 新增長度錯誤，並設為 Equatable
- 2026-11-05 · 已決定（Agent，實作 M1 時補）
- 決定：ARCHITECTURE §6 的 `AnalysisError` 增加 `videoTooShort(seconds:)`、`videoTooLong(seconds:)`，並讓整個 enum 符合 `Equatable`。放在 VBTCore，供 VBTVision 與 App 層共用。
- 原因：PRD §3.3 要求阻擋長度 < 1 秒或 > 3 分鐘，但原本 §6 的錯誤列舉沒有對應案例（規格缺口，非牴觸）。Equatable 讓驗證邏輯能直接用 `#expect(... == .videoTooShort)` 寫測試。
- 替代：用 `videoUnreadable` 混充（使用者看到的錯誤文字會不準，不採用）。

## D-016 低影格率提示顯示在剪輯頁
- 2026-11-05 · 暫定（Agent，實作 M1 時決定）
- 決定：影格率 < 50 fps（`VideoInfo.isLowFrameRate`）時不阻擋；非阻擋提示「建議用 60fps 錄影，速度會更準」顯示在**剪輯頁**（選片後第一個會停留的畫面），不在設定頁短暫閃現。
- 原因：選片通過檢查後流程直接推進到剪輯頁，設定頁不會停留；在剪輯頁顯示才看得到。文字與 PRD §3.3 逐字一致（無句號）。
- 替代：選片當下用 toast／alert 顯示（流程會多一次中斷，MVP 先不做）。

## D-017 匯入影片用搬移（move）而非複製，減少等待
- 2026-11-05 · 暫定（Agent，實機發現載入慢後調整）
- 決定：PhotosPicker 交出的暫存檔通過 `VideoInspector` 檢查後，用 `FileStore.moveIn`（`moveItem`）搬進 `Application Support/Videos/`，不再 `copyItem`。暫存檔與 App 容器在同一 volume，move 近乎即時。
- 原因：原本先「相簿→暫存」複製一次、再「暫存→Videos」複製一次，大檔要兩倍時間。改 move 省掉第二次整檔複製。相簿輸出原檔（含 iCloud 下載）的耗時屬系統層，無法在 App 端消除。
- 替代：維持兩次複製（慢）；或延後到剪輯「完成」才收檔（MVP 不需要）。

## D-018 PhotosPicker 用 .current 編碼，避免 HDR 轉碼
- 2026-11-06 · 已決定（使用者）
- 決定：`PhotosPicker` 設 `preferredItemEncoding: .current`，拿原始編碼、不轉碼。原本預設 `.automatic` 會把 iPhone 的 HEVC + Dolby Vision HDR 影片轉成 SDR 相容格式，實機上 53 秒 HDR 影片要 13–15 秒才載入；同規格 SDR 幾乎瞬間。
- 影響：匯入的是影片原始格式（iPhone→HEVC/HDR 10-bit；他機→可能 H.264/SDR 8-bit），不強制統一。分析（M2）用 `AVAssetReader` 逐幀解碼輸出 8-bit，Vision 追蹤不受 HDR 影響，不需整檔轉檔。未來疊圖匯出（V1.2）若要簡化合成，可在匯出當下再 tone-map 成 SDR——保留原始 HDR 不會卡住該決定，反而無損。不需新權限、仍只用 PhotosPicker。
- 替代：`.compatible`（一律轉碼，最慢）；或 `.automatic`（預設，HDR 慢）。

## D-019 HDR 視覺一律以實機為準；模擬器無法正確顯示 HDR
- 2026-11-07 · 已確認（使用者實測）
- 現象：改用 `.current`（D-018）保留原始 HDR 後，影片在 **iOS 模擬器** 的 `VideoPlayer` 與縮圖會嚴重偏色／過曝（青藍、洋紅、過亮）；相簿本身在模擬器看也過曝。同一支影片在**實機顯示完全正常**。
- 原因：模擬器跑在 Mac GPU 上，不會正確模擬 HDR / Dolby Vision（BT.2020 PQ、10-bit）的解碼與顯示，這是 Apple 模擬器長年限制，不是 App 的 bug。
- 決定：**不加 workaround**。HDR 的顏色/視覺一律以實機驗證；模擬器只用來測版面、流程、邏輯。純屬顯示問題，不影響像素資料；M2 追蹤用 `AVAssetReader` 逐幀解碼成 8-bit，且追蹤不看顏色，不受影響。
- 備查：若開發期真的需要，可用 `#if targetEnvironment(simulator)` 只在模擬器把預覽 tone-map 成 SDR，實機不動——目前判斷不值得，未採用。

## D-021 FrameReader 採拉取式 API，不用 AsyncThrowingStream
- 2026-11-07 · 暫定（Agent，實作 M2 時決定）
- 決定：`FrameReader` 是非 `Sendable` 的 `final class`，用同步的 `next() throws -> Frame?` 一次拉一幀，而非 ARCHITECTURE §3 原寫的 `AsyncThrowingStream<Frame>`。`Frame` 內保留來源 `CMSampleBuffer` 以固定 `CVPixelBuffer` 的記憶體生命週期（`alwaysCopiesSampleData = false`）。整個讀取器生命週期留在單一 context（未來的 `AnalysisPipeline` actor）內，`Frame` 不跨 actor 傳遞。
- 原因：Swift 6 嚴格並行下，`CVPixelBuffer`/`Frame` 非 `Sendable`，用 `AsyncThrowingStream` 需 `@unchecked Sendable`（swift-style 禁止）或預先緩衝；而緩衝整段影片會記憶體爆量、丟幀政策會破壞逐幀分析。解碼本身同步，拉取式最貼合用途：有界記憶體、不丟幀、不需 Sendable hack。與 D-011 同精神（Swift 6 並行驅動的設計調整）。ARCHITECTURE §3 已同步更新。
- 替代：`AsyncThrowingStream` + `alwaysCopiesSampleData = true` + `@unchecked Sendable`（違反 swift-style，且需緩衝權衡）。

## D-022 新增 AnalysisParameters 與追蹤遺失門檻
- 2026-11-07 · 暫定（Agent，實作 M2 時補）
- 決定：在 VBTCore 建立 `AnalysisParameters`（ALGORITHMS §7 全部參數）供追蹤與後續 M3／M4 共用，並新增三個追蹤遺失門檻：`maxCenterJumpFactor = 0.5`（× 槓片直徑）、`maxAreaGrowthFactor = 2.0`、`minAreaShrinkFactor = 0.5`（數值取自 skill plate-tracking §3）。ALGORITHMS §7 已加對應列。同時新增 `TrackSample`、`PlateSelection` 兩個值型別（定義見 ARCHITECTURE §2）。
- 原因：「所有可調整數值放進 AnalysisParameters」（vbtkit 規則）；§7 原本缺追蹤遺失門檻（規格缺口，非牴觸）。這些是追蹤階段參數，影響的是原始 `TrackSample` 的產生，改值需重新追蹤，與 `analysisVersion`（從既有樣本重算）無關，故**不**升版，維持 `analysisVersion = 1`。
- 替代：門檻寫死在 `PlateTracker`（違反 no-magic-numbers 規則）。

## D-023 合成影片追蹤準確度門檻：每幀 < 2 px、平均 < 1.5 px
- 2026-11-07 · 已決定（使用者）
- 決定：合成「移動圓盤」端對端測試，在近真實一下的中等運動速度（≈2 px/幀）斷言每幀中心誤差 < 2 px、平均 < 1.5 px；直/橫拍一致 < 2 px。skill accuracy-check §2 原寫「平均 < 1 px」改為「平均 < 1.5 px」。
- 原因：量測發現 `VNTrackObjectRequest` 的框中心即使槓片**完全靜止**也有 ~0.9 px 固有偏差（dx≈−0.6、dy≈0.7），並隨速度略增（快速時每幀最大 ~3 px）；`bestShift = 0` 排除單純時間延遲。此為 Vision 追蹤器本身精度，非管線錯誤（翻轉／比例錯誤會是上百 px）。ROADMAP「每幀 < 2 px」在中等以下速度可達成；「平均 < 1 px」不可達。
- 連帶：真實影片的追蹤準確度無法在模擬器判斷，列入 OPEN_QUESTIONS Q10 由實機驗證；若實機不足，再評估 plate-tracking §4 的強化手段（輪廓重定位／CoreML，需先問）。
- 替代：保留 < 1 px 平均並加強追蹤器（超出 MVP，未採用）。

## D-024 真實影片驗證策略：M2 以實機手動為主，合成影片為自動化關卡（回答 Q6、Q7）
- 2026-11-07 · 已決定（使用者）
- 決定：M2 的自動化測試只用合成影片當關卡；真實影片（`TestVideos/`，6 段，不 commit）由使用者在實機點選槓片、目視確認追蹤沒跑掉。測試會偵測 `TestVideos/` 旁的同名 `.json` sidecar（格式見 skill accuracy-check §3），有就跑真實影片端對端、沒有就跳過（目前 6 段都無 sidecar，故跳過）。實機型號：A18（HEVC + HDR 來源），Apple Developer Team `QQ5995JYJH`。
- 原因：真實影片的 `PlateSelection`（點選圓心）需透過 App UI 才取得，難以手寫 sidecar；追蹤準確度本來就需實機（模擬器 HDR 偏色、無法判斷，D-019）。回答了 OPEN_QUESTIONS Q6、Q7。
- 替代：要求使用者手寫 sidecar 預期值（不便，未採用）。

## D-025 在 M3 之前插入「追蹤驗證」步驟（TrackingRunner + 疊點重播 + log）
- 2026-11-07 · 已決定（使用者）
- 決定：先讓使用者能在**真實影片**上目視確認追蹤正確，再投入速度計算。新增 `TrackingRunner`（VBTVision `actor`，串 `FrameReader → PlateTracker` 產生 `[TrackSample]`，`os.Logger` category `Tracking` 記參數/每幀 center·信心·缺漏/結尾摘要與跟丟時間；跟丟不丟錯而回傳 `TrackingRun.lostAtTime`）；App 新增追蹤預覽頁（`TrackingPreviewView` 重播剪好片段、紅點跟槓片、畫整條軌跡線、狀態列），「鎖定並追蹤」接進此頁。`PlateSelection` 加 `Hashable` 供導覽路由。
- 原因：使用者正確指出「先確認追蹤對、再算才有意義」。原 ROADMAP 疊圖重播排在 V1.2，但那是成品功能；此為開發期驗證工具，且 `TrackingRunner` 正是 M4 `AnalysisPipeline` 的追蹤段，不浪費。
- 影響：追蹤技術為 Apple Vision `VNTrackObjectRequest`（通用物件追蹤，不看顏色、非槓片專用偵測），真實影片準確度仍需實機驗證（Q10）。追蹤框 vs 使用者圓圈的 25% 比例尺差異警告（ALGORITHMS §1）尚未納入 log，留待 M4。
- 替代：直接做 M3、追蹤可視化等 M5 結果頁（使用者否決，因無法及早驗證追蹤）。

## D-020 匯入時記錄載入耗時與影片資訊（os.Logger）；VideoInfo 增加 codec/isHDR
- 2026-11-07 · 已決定（使用者）
- 決定：`VideoSetupView.handlePicked` 用 `os.Logger`（subsystem `com.kun0606.AllMight`、category `VideoImport`）記兩行：(1) 載入各階段耗時 `transfer / inspect / store`（秒）；(2) 影片資訊 `codec、hdr、解析度、fps、方向、長度、低影格率`。方便日後查資訊與抓 bug（例如這次的 HDR 問題）。
- 連帶：`VideoInfo` 新增 `codec: String`（FourCC，如 "hvc1"/"avc1"）與 `isHDR: Bool`。codec 由 `CMFormatDescriptionGetMediaSubType` 取得；isHDR 由 `AVMediaCharacteristic.containsHDRVideo` 判斷（系統從 format description 推斷，比解析 transfer function 乾淨）。
- 保留 log：使用者同意先留著計時與資訊 log（非 `print`，符合 swift-style 用 `os.Logger` 的規則），之後要拿掉再說。

## D-026 M3 速度計算：管線型別與 ALGORITHMS §3 缺口的工程決定
- 2026-11-08 · 暫定（Agent，實作 M3 時決定；經 algorithm-reviewer 審查）
- 背景：M3 實作 `Calibrator`、`GapFiller`、`Resampler`、`SavitzkyGolay`、`Kinematics.computeSeries`，純 VBTCore。沒有改任何 §1–§4 公式或 §7 預設參數，故 `analysisVersion` 維持 1。以下是規格未明寫、由實作補齊的幾點：
  1. **開頭/結尾缺漏的處理（§3 缺口）**：§3 只定義「連續缺漏 ≤ maxGapFrames 線性內插、超過 trackingLost」，但落在片段開頭或結尾的缺漏**沒有兩側有效點可內插**。決定：這類缺漏若 ≤ maxGapFrames 就**丟棄**那幾幀（等間隔網格晚一點開始／早一點結束），> maxGapFrames 仍丟 `trackingLost`。原因：開頭/結尾本就少數幀，丟棄不影響動作段；硬補值會引入假資料。
  2. **原點取第一個樣本**：§2 寫 `y[0]` 為原點，實作即取 `samples.first`。原點是常數位移，不影響速度與 ROM（皆為相對量），即使首幀略有雜訊也只平移絕對位置。
  3. **`Resampler` 浮點掉尾幀修正**：`span/dt` 剛好是整數時浮點可能算成 `k−ε`（如 0.3/0.1 = 2.999…），`floor` 會少一格而掉掉尾幀——正是 §8「最後放下槓鈴／從動作中間開始」會踩到的情境。改為 `floor(span/dt + 1e-9) + 1`，並強化 `ResamplerTests` 斷言尾端貼齊 `tEnd`。
  4. **`KinematicSeries` 欄位**：除 ARCHITECTURE §2 列的時間/位置/速度外，另存**加速度**（§6 MPV 要找 `a < −9.81`，M4 用）、**水平位置**（§2「只用來畫軌跡」）與 **scale**（§1，供 M4 的 25% `scaleMismatch` 警告）。都在 M3 已可免費算出，先存免得 M4 重算。
  5. **PV 不是 §8 的 M3 驗收門檻**：§8 只要求 MV < 0.02 m/s、ROM < 1 cm、次數正確。峰值速度 PV = `max(v)`（§6）對雜訊敏感：σ=2px 時 60fps 約 +13%、30fps 約 +25%（SG 導數在較大 dt 放大單點雜訊，也是 D-016 推薦 60fps 的原因）。測試對 PV 只做寬鬆 sanity 檢查（0.15 m/s），完整 PV／「次數」驗收待 M4 `RepSegmenter` 與 `AnalysisPipeline`。
- 驗證：合成**訊號**（VBTCoreTests）與合成**影片→真實 Vision 追蹤**（VBTVisionTests `KinematicsVideoTests`）兩路端對端皆達 §8 門檻；`swift test` 79/79。
- 替代：開頭/結尾缺漏改用最近有效值外插（會造假位移，未採用）；`KinematicSeries` 只存速度、M4 重算加速度（重複計算，未採用）。

## D-027 M4 次數切分與指標：minROM、scaleMismatch 與相位邊界定義
- 2026-11-09 · 已決定（使用者 + Agent，實作 M4 時決定；經 algorithm-reviewer 審查）
- 背景：M4 實作 `RepSegmenter`（§5）、`MetricsCalculator`（§6）、新型別（`Phase`/`PhaseKind`/`PhaseMetrics`/`RepMetrics`/`SetSummary`/`SetAnalysis`，純 VBTCore）與 `AnalysisPipeline`（VBTVision actor，串追蹤→運動學→切分→指標，`AsyncThrowingStream<AnalysisProgress>` 回報進度、支援取消）。沒有改任何 §1–§6 公式或 §7 預設參數，故 `analysisVersion` 維持 1。決定如下：
  1. **minROM 全動作單一值 0.10 m（回答 Q8）**：使用者決定 M4 五個動作都用 `AnalysisParameters.minROM = 0.10 m`，不改參數結構；各動作差異留到 M7 用真實影片實測再調。`RepSegmenter` 直接讀 `parameters.minROM`。
  2. **scaleMismatch（§1 的 25% 比例尺差異警告）延到 M7**：此警告需「追蹤框寬度中位數」，但 `TrackSample` 目前不帶框寬（D-006 只用中心點）。使用者決定 M4 **不做**，保持切分/指標為純 VBTCore、不動 `TrackSample` 格式與現有 VBTVision 測試；留到 M7 用真實影片時再加 `TrackSample.boxWidth` 並實作警告。非阻擋性旗標，延後不影響 MVP 數值正確性。
  3. **相位邊界＝位置轉折點（§5 的工程澄清）**：§5 寫「階段起點往前回推到 v 跨過 0 的那一點（讓位移與時間完整）」。實作上，向心/離心的核心先以「速度連續 ≥ minPhaseSeconds 超過 velThreshold」偵測（去抖），再把核心**兩端**都向外延伸到位置的局部極值（＝速度跨 0）。用位置極值而非直接找速度零點，是因為極值附近速度≈0、雜訊會左右正負號，直接找零點會讓每下少算 1–2 幀、使 MV 被高估（實測 σ=2px 時某下 MV 誤差衝到 0.020）；改用位置轉折點後三下 MV 誤差回到 −0.008…+0.003 m/s，穩穩在 §8 的 0.02 門檻內。此為對「讓位移與時間完整」的忠實落實，未改任何既有公式/預設值，`analysisVersion` 維持 1。ALGORITHMS §5 已補此澄清。
  4. **TrackingRun 增 geometry、TrackingRunner 增選用 onProgress**：`AnalysisPipeline` 重用 M2.5 的 `TrackingRunner`（D-025），需要轉正幾何給 `Kinematics`，故 `TrackingRun` 加 `geometry: VideoGeometry`；並加選用 `onProgress` 逐幀回報追蹤進度。皆為加法式變更，不影響既有呼叫（App 追蹤預覽頁不受影響）。`AnalysisProgress` 放 VBTVision（靠近 `AnalysisPipeline`）。
- 驗證：`swift test` 98/98（VBTCore 新增 `RepSegmenterTests` 10、`MetricsCalculatorTests` 6；VBTVision 新增 `AnalysisPipelineTests` 3）；涵蓋 §8 全部邊界（1 下／沒動作／從動作中間開始／最後放下槓鈴／缺漏=maxGapFrames／30fps/60fps/變動影格率）、兩種動作順序配對、MPV 推進段界定、速度損失、restAfter；合成影片端對端次數=3、取消 < 0.5 秒停止。App `xcodebuild test` 14/14（VBTVision API 加法式變更相容）。
- 替代：各動作不同 minROM（無真實影片依據，未採用）；M4 就加 boxWidth 做 scaleMismatch（跨到 VBTVision 追蹤輸出與測試，範圍過大，未採用）；相位邊界直接找速度零點（雜訊敏感、MV 高估，未採用）。

## D-028 M5 分析中／RPE／結果頁：流程接點、軌跡線（回答 Q4）、不持久化、速度曲線範圍標示延後
- 2026-11-09 · 已決定（使用者 + Agent，實作 M5 時決定；經 ios-reviewer 審查）
- 背景：M5 全為 App 層 SwiftUI，串起「分析中 → RPE → 結果頁」整條流程，重用 M4 的 `AnalysisPipeline`（VBTVision actor）。未動 Packages/VBTKit，`analysisVersion` 維持 1。決定如下：
  1. **流程接點（使用者決定）**：點選槓片 →「鎖定並追蹤」→ 追蹤驗證頁（M2.5 `TrackingPreviewView`，加一顆「開始分析」按鈕）→ 分析中（`AnalysisProgressView`）→ RPE sheet → 結果頁。保留追蹤驗證頁當「分析前的目視安全檢查」，因真實影片追蹤準確度（Q10）要到 M7 才實機驗證；M7 驗證通過後可再切成 FLOW.md 的正式路徑（點選槓片直接進分析）。**RPE 在看結果之前**選（符合 FLOW、PRD §3.6→3.7→3.8）。
  2. **結果頁畫一條槓鈴軌跡線（回答 Q4）**：使用者決定在結果頁播放器上疊一條軌跡線（非完整疊圖，完整疊圖仍是 V1.2）。由 `series`（公尺，相對第一樣本，`scale`=m/px）以 `selection.center`（Vision 正規化）為錨點反推回正規化座標、再換算顯示座標（與 `TrackingPreview` 疊點同一套映射，`Calibrator` §2 正向公式的逆運算）。不需改 VBTKit、不需把原始 `TrackSample` 帶進 `SetAnalysis`。
  3. **M5 不持久化（使用者確認）**：結果頁只呈現記憶體中的 `SetAnalysis`，不寫 SwiftData、不存樣本檔。儲存與歷史（`WorkoutSet`）留 M6。結果頁摘要卡暫不放「編輯」按鈕（編輯是 M6）。
  4. **導覽路由**：`ResultContext`（含 `SetAnalysis` + 設定值 + `rpe`/`isWarmup` + clip/trim/selection）以 `id: UUID` 作 `Hashable`（`SetAnalysis` 非 Hashable）。錯誤/取消用 `popLast(n)` 退回對應步驟：追蹤遺失與取消回點選槓片（PRD §3.6「回 3.5」）、沒偵測到次數回剪輯（「回 3.4」）。RPE sheet 加 `interactiveDismissDisabled()`，必須明確選一項（含「跳過」）才離開，避免滑掉 sheet 卡在分析中頁（ios-reviewer 指出的死路）。
  5. **速度曲線「逐下標示範圍」延後**：PRD §3.8 要求速度曲線標出每一下的範圍（R1、R2…），但 `SetAnalysis.reps`（`RepMetrics`）**不含相位的起訖時間**（`PhaseMetrics` 只有 duration/MV/PV/位移）。要精確標範圍需把相位時間（或 `Phase` 的 time 區間）帶進 `SetAnalysis`——屬 VBTKit 型別變更，M5 刻意不做。M5 的速度曲線先畫面積曲線 + 拖曳讀值（`chartXSelection`），逐下範圍標示待日後決定是否擴充 VBTKit 輸出（見 OPEN_QUESTIONS Q11）。
- 驗證：`BuildProject` 成功、`swift test` 99/99（VBTKit 未動）、App `xcodebuild test` 19/19（iPhone 17，新增 `FormattersTests` 5：PRD §3.8 速度/cm/%/秒格式）。ios-reviewer 審查：修正 RPE sheet 滑掉卡死（must-fix）、補速度曲線 VoiceOver 文字替代、摘要字串改 Text 插值、Formatters 固定 `en_US_POSIX` 小數點。真實影片端對端數值與 VoiceOver 實地體驗待使用者實機驗證（Q10）。
- 替代：分析取代追蹤驗證頁成為正式流程（使用者選擇保留驗證頁至 M7）；把原始 `TrackSample` 或相位時間帶進 `SetAnalysis` 以利軌跡/範圍標示（M5 不需要，延後）。

## D-029 圈選大小同時影響追蹤穩定度與比例尺校正（實機觀察，改善列入 M7）
- 2026-11-10 · 已決定（使用者：先維持現狀、列入 M7 待做）
- 背景：使用者實機測試背蹲舉（側拍），在追蹤驗證頁比較不同圈選大小。信心 97–98%、未跟丟、844 樣本；但**圈畫大時軌跡線左右抖、圈貼齊槓片時滑順**。
- 原因（已核對程式 `PlateTracker.initialBoundingBox`）：使用者畫的圈直徑 = Vision `VNTrackObjectRequest` 初始追蹤框邊長。圈大 → 框把背景、深蹲架直立桿、槓鈴桿等強邊緣框進去 → 每幀重估框邊界時框中心漂移 → 追蹤驗證頁畫的是**原始框中心（未平滑）**，故水平抖動直接可見；且 `maxCenterJumpPx = 0.5 × diameterPx` 也隨圈變大而放寬、過濾更鬆。圈貼齊圓形高對比槓片時框穩、線滑順。
- 對數值的影響：水平抖動**不進速度/ROM**（只用垂直位置，x 僅畫軌跡）；垂直雜訊由 Savitzky-Golay 平滑，MV/ROM 穩、PV 較敏感。真正系統性風險是**校正**：圈同時決定 `scale = plateDiameterCm/100/diameterPx`（D-006），圈比槓片實際外緣大 → diameterPx 偏大 → scale 偏小 → 速度與 ROM 整體被低估（圈大 ~20% ≈ 低估 ~20%）；圈比槓片小則反向高估。
- 決定：**先維持現狀**（正確用法＝圈貼齊槓片外緣，畫面已有提示「調整圓圈貼齊槓片外緣」）；不動 VBTKit。改善列入 ROADMAP M7：(a) 落地 D-027 的 scaleMismatch 警告（追蹤框大小 vs 使用者圈差太多 → 提示重畫）；(b) 追蹤驗證頁軌跡線顯示時加平滑（純視覺）；(c) 點選槓片頁加強貼齊引導。
- 替代：現在就改追蹤或加平滑（非 MVP 必要，追蹤信心已高，未採用）。

## D-030 M6 儲存與歷史：樣本來源、自動儲存、結果頁解耦、編輯範圍
- 2026-11-11 · 已決定（使用者，開工前拍板「全部照建議」；實作 M6 時決定；經 algorithm-reviewer + ios-reviewer 審查）
- 背景：M6 全為 App 層接線，但需要原始 `TrackSample[]` 來存檔與「用樣本重算（不重新追蹤）」。`AnalysisPipeline` 原本只回 `SetAnalysis`、丟掉樣本。以下五點由使用者拍板：
  1. **樣本來源與重算＝(a)+(b) 都做（加法式、不改公式，`analysisVersion` 維持 1）**：
     - (a) `AnalysisPipeline` 在 `.finished` 一併帶出 `[TrackSample]`（`AnalysisProgress.finished(SetAnalysis, samples:)`）。
     - (b) 新增 VBTCore 純函式 `SetAnalyzer.analyze(samples:selection:geometry:plateDiameterCm:exercise:parameters:) -> SetAnalysis`，抽出原本 inline 於 `runPipeline` 的 Kinematics→RepSegmenter→MetricsCalculator 鏈；`AnalysisPipeline` 內部改呼叫它，使「即時分析」與「升級重算」走同一段程式、保證等價（`SetAnalyzerTests` 驗等價與 trackingLost/noReps 兩條錯誤契約）。升級重算在 `WorkoutStore.recomputeIfNeeded`。回答 D-007／ARCHITECTURE §4.2。
  2. **自動儲存時機＝選完 RPE、進結果頁前**：`HomeView` 的 RPE 完成 callback 呼叫 `WorkoutStore.save`（寫 `Samples/<id>.json` + 插入 `WorkoutSet`），結果頁改讀已存紀錄（帶 `recordID`）。非結果頁上的手動按鈕。存檔失敗不擋看結果（記 log、`recordID=nil`、該次不進歷史也不能編輯、隱藏「編輯」）；DB 失敗時清掉剛寫的孤兒樣本檔。
  3. **結果頁與 `VideoClip` 解耦＝改吃 `url+geometry`**：`ResultContext`/`ResultModel`/`ResultView` 不再依賴 `VideoClip`/`VideoInfo`；新增 `ResultContext(set:fileStore:)` 由 `WorkoutSet` 解碼（`videoFileName`→FileStore URL、`geometryData`→`VideoGeometry`），讓「新分析」與「歷史重看」共用同一結果頁。
  4. **編輯範圍＝只重量與 RPE、不重算**：比例尺用 `plateDiameterCm` 不是 `load`，重量/RPE 是中繼資料不影響分析數值，故 `WorkoutStore.updateMetadata` 只改欄位、不動 `analysisData`（`updateMetadataKeepsAnalysis` 驗證）。不編輯動作/直徑/片段（直徑若可編會牽動重算與軌跡校正）。符合 PRD §3.8/§3.9。
  5. **範圍：Q11（速度曲線逐下標示範圍）與 D-029（追蹤/校正改善）不在 M6**，維持預設延後（Q11 待是否擴充 `SetAnalysis` 相位時間；D-029 在 M7）。
- 連帶工程決定：`FileStore` 加 `write/read`（樣本 JSON 的讀寫仍集中在 FileStore，符合 privacy-and-files）；`WorkoutStore`（App 層、持有 `ModelContext`，App 預設 MainActor 隔離故為 MainActor-isolated、不標 Sendable）；`analysisVersion` 升級重算在進歷史頁 `.task` 統一跑（不在 view body 內改 SwiftData，避免 modifying-state-during-update）。
- 6. **影片檔單一擁有者 + 刪除後結果頁一致性（實機發現，2026-11-11）**：匯入的影片檔（Videos/<name>）在「當前分析流程」與「存檔後的紀錄」間是同一個檔（存檔不另複製，省空間）。實機發現：看完結果頁後若「返回」會倒退進已消耗的點選槓片/追蹤驗證/分析頁，那些頁仍握著該影片檔；若此時到歷史把該筆刪掉（連同影片檔），倒退回去的頁會讀不到檔（點選槓片頁一直轉圈、再分析丟 `videoUnreadable`）。決定：(a) 分析完成並存檔後把訓練堆疊**重設成只剩結果頁**（`path = [.result]`），讓「返回」回訓練首頁、不再回到消耗過的流程——同時使影片檔在存檔後只剩「紀錄」單一擁有者，並避免倒退重跑產生重複紀錄；(b) 結果頁用 `@Query` 反應式盯住自己的 `recordID`，被刪時切到「已刪除」狀態：影片播放器換成「影片已刪除」佔位、頂部顯示「這筆紀錄已被刪除，如需要請重新分析。」、隱藏「編輯」，但分析數字/曲線/次數仍從記憶體照常呈現。驗證：App build + test 綠（23/23）；導覽與 @Query 刪除狀態屬 UI 行為，需使用者實機驗證。替代：存檔時把影片複製成紀錄專屬檔（雙倍儲存、且會留下 session 匯入的孤兒檔，未採用）。
- 驗證：`swift test` 103/103、App `xcodebuild test` 23/23（iPhone 17）。reviewer 處理項：統一 RPE 顯示格式（新增 `Formatters.rpe`，RPEPickerSheet/EditSetSheet/ResultView 共用，避免 locale 造成 `7,5`/`7.5` 不一致）、未存檔隱藏「編輯」、存檔失敗清孤兒樣本檔、`HistoryView` 重算/刪除改記 log、HistoryRow 合併 VoiceOver、EditSetSheet Stepper 補 accessibilityValue、強化 `SetAnalyzer` 等價與 trackingLost 測試、補 HistoryView `#Preview`。
- 替代：只做 (a)（重算邏輯散在 App、難測等價）或只做 (b)（拿不到樣本）；(c) 升級時重新追蹤（違背 D-007、慢）；結果頁手動儲存按鈕（與「自動存」不符）；維持吃 `VideoClip`（歷史重看需造 `VideoInfo`，彆扭）。皆未採用。

## D-031 M7 Q11：速度曲線逐下範圍標示 — PhaseMetrics 帶相位時間、analysisVersion 升 2
- 2026-11-11 · 已決定（使用者，M7 開工前拍板「做」；實作時決定相容策略）
- 背景：PRD §3.8 要求速度曲線標出每一下的範圍（R1、R2…），但 `RepMetrics`/`PhaseMetrics` 原本不含相位的起訖時間（M5 D-028 第 5 點刻意延後）。M7 把它補上。
- 決定：
  1. **加法式型別變更**：`PhaseMetrics` 新增 `startTime: Double?`、`endTime: Double?`（秒，相對片段起點），由 `MetricsCalculator` 從 `Phase.startTime/endTime` 帶出。向心相位的 `[startTime, endTime]` 即該下在時間軸上的範圍；結果頁 `VelocityChart` 以 `RectangleMark` 淡色區塊標出並標籤 R1、R2…。不改 §6 任何數值公式。
  2. **欄位設 optional**：`recomputeIfNeeded` 以「完整解碼 `SetAnalysis` 讀版本」判斷是否升級重算；若新欄位為必填，M6 舊 `analysisData`（無此欄位）會在版本檢查前解碼失敗。改為 optional 後，舊 JSON 解碼為 nil、任何讀取路徑（結果頁/重算版本檢查）都不會崩；顯示層對 nil 略過範圍標示。
  3. **`analysisVersion` 由 1 升為 2**：純為觸發 M6 舊紀錄經既有升級重算（`WorkoutStore.recomputeIfNeeded`→`SetAnalyzer.analyze`）補上相位時間欄位；重算產生的數值與原本完全相同，只多了新欄位。回答 Q2「版本維持或小升」：採「小升」，因使用者希望舊紀錄也能顯示範圍。配合升版更新 `VBTCoreTests`/`VBTVisionTests` 的版本斷言。
- 驗證：`swift test` 104/104（VBTCore 新增 `MetricsCalculatorTests.phaseTimesMatchSegmentation`：相位時間與切分一致、等於網格時間戳、duration 一致、遞增；升版斷言）；App `xcodebuild test` 23/23（iPhone 17）；`BuildProject` 成功。回答 OPEN_QUESTIONS Q11。
- 替代：`analysisVersion` 維持 1、舊紀錄永不補欄位（最省，但使用者想要舊紀錄也顯示範圍，未採用）；相位時間放 `RepMetrics` 層而非 `PhaseMetrics`（較不忠實於 `Phase`、離心範圍拿不到，未採用）；非 optional + 讓重算只解碼版本欄位（需改動解碼路徑且其他讀取點仍會壞，未採用）。

## D-032 M7：scaleMismatch 比例尺警告落地（TrackSample.boxWidth、Calibrator.scaleMismatch）
- 2026-11-11 · 已決定（使用者，M7 開工前拍板「做；optional boxWidth、版本維持」；實作時決定細節）
- 背景：使用者圈同時兼作比例尺（`scale = 槓片公分 / 圈直徑px`，D-006），圈沒貼齊槓片外緣會整體高/低估速度與 ROM（D-029 實機觀察）。ALGORITHMS §1 一直規劃「追蹤框寬 vs 圈直徑差 > 25% → 警告」，但需 `TrackSample` 帶框寬（D-006 原只存中心點），M4 刻意延到 M7（D-027）。
- 決定：
  1. **`TrackSample` 加 optional `boxWidth`（Vision 正規化框寬）**：`PlateTracker` 在追蹤到的幀帶出 `box.width`（首幀回傳使用者圈、缺漏幀為 nil）。optional 以相容升級前存的 `Samples/<id>.json`（舊 JSON 無此欄位 → nil）。`TrackSample` 不在 `SetAnalysis` 內，故不影響 `SetAnalysis`/`AnalysisParameters` 的解碼。
  2. **`Calibrator.scaleMismatch(samples:selection:geometry:thresholdFraction:minSamples:)` 純函式**：取帶框寬樣本的框寬中位數（換算 px）與 `selection.diameterPx` 相對比較，差 > `thresholdFraction`（預設 `scaleMismatchThreshold = 0.25`）回 true；帶框寬樣本 < `minSamples`（預設 10，含全為 nil 的舊樣本）回 false。
  3. **門檻放「具名常數/函式預設參數」，不放 `AnalysisParameters`**：因 `AnalysisParameters` 被編碼進 `SetAnalysis`，加必填欄位會讓 M6 舊紀錄解碼失敗（`recomputeIfNeeded` 讀版本前需完整解碼）。scaleMismatch 門檻只影響「是否顯示警告」、從不參與重算或存檔，放具名常數（符合 swift-style「魔術數字放 AnalysisParameters 或具名常數」）最簡單、零相容風險。
  4. **`analysisVersion` 維持（本變更不升版）**：`boxWidth` 不進任何速度/ROM 公式（比例尺仍用使用者圈，D-006），警告為 live 計算、不存進 `SetAnalysis`，故無數值變化、不需重算。（版本目前為 2，來自 D-031 的 Q11。）
  5. **顯示在追蹤驗證頁**：`TrackingPreviewModel` 追蹤完成後以 `Calibrator.scaleMismatch` 算旗標，`TrackingPreviewView` 在 `.ready` 時顯示非阻擋性警告橫幅，提示「返回上一步重新圈選、貼齊槓片外緣會更準」。選在此頁因它是分析前的目視檢查點、且已有樣本（歷史重看不需此 live 警告）。
- 驗證：`swift test` 109/109（VBTCore 新增 `CalibratorTests` 4：觸發/容忍內/無框寬/樣本太少；VBTVision 新增 `PlateTrackerTests.samplesCarryBoxWidth`：追蹤幀帶正框寬且與槓片同數量級）；App `xcodebuild test` 23/23（iPhone 17）；`BuildProject` 成功。**25% 門檻的實地校準、以及真實影片上是否會誤報/漏報，屬 M7 第二階段（需使用者實機 + 真實影片）。**
- 替代：把 boxWidth 另存分離 sidecar（較複雜、與樣本格式脫鉤，未採用）；門檻放 `AnalysisParameters`（破壞 M6 舊紀錄解碼，未採用）；警告放結果頁或存進 `SetAnalysis`（需把框寬帶進 `SetAnalysis`、且歷史重看不需 live 警告，未採用）。
