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
