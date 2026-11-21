# 演算法規格（公式與參數的唯一來源）

改這份文件裡的任何公式或預設值時：同步改程式、改測試、把 `analysisVersion` +1、在 DECISIONS.md 記錄。

## 0. 座標與單位
- 追蹤座標使用 **Vision 正規化座標**：0–1，原點在**左下**，以**轉正後**的影像為準。所以 y 越大越高，向上為正，不需要再翻轉。
- SwiftUI 點擊座標（原點左上）轉 Vision：`xN = x / viewW`，`yN = 1 − y / viewH`（view 必須與影像等比例顯示，扣掉 letterbox）。
- 內部單位一律 SI：公尺、秒、m/s、m/s²。只在顯示時換成 cm。

## 1. 比例尺
```
scale (m/px) = plateDiameterCm / 100 / selection.diameterPx
```
- `diameterPx` 來自使用者調整的圓圈，以轉正後影像像素為準。
- 檢查（scaleMismatch，M7 落地）：Vision 追蹤框寬度中位數（換算 px）與 `diameterPx` 相對相差 > 25%（`Calibrator.scaleMismatchThreshold`）→ 非阻擋性警告，提示使用者圈可能沒貼齊槓片、建議重畫。`TrackSample` 新增 optional `boxWidth`（Vision 正規化框寬，首幀與缺漏為 nil），`PlateTracker` 輸出、`Calibrator.scaleMismatch(...)` 比對。**只影響是否顯示警告、不影響任何數值**，故門檻可調且不觸發 `analysisVersion` 升版；帶框寬樣本不足（含升級前舊樣本）時不警告。顯示在追蹤驗證頁。見 DECISIONS D-032（原 D-006/D-027/D-029）。

## 2. 位置
```
y_m[i] = (y[i] − y[0]) × heightPx × scale
x_m[i] = (x[i] − x[0]) × widthPx  × scale     // 只用來畫軌跡
```

## 3. 缺漏處理與重新取樣
1. 信心 < `minConfidence` 的樣本視為缺漏。
2. 連續缺漏 ≤ `maxGapFrames` → 線性內插；超過 → `trackingLost(atTime:)`。
3. 依時間戳線性內插到等間隔網格 `dt = 1 / nominalFPS`（影片可能是變動影格率）。

> 落在片段**開頭或結尾**的缺漏沒有兩側有效點可內插：若 ≤ `maxGapFrames` 則丟棄那幾幀（等間隔網格晚一點開始／早一點結束），> `maxGapFrames` 仍丟 `trackingLost`（見 DECISIONS D-026）。

## 4. 平滑與微分（Savitzky-Golay）
- 視窗長度 `N = 奇數(round(sgWindowSeconds × fps))`，最少 5。多項式階數 `sgOrder`。
- 用 SG 係數同時求：平滑位置 `p`、一階導數 `v`（÷dt）、二階導數 `a`（÷dt²）。
- 邊界：前後各 (N−1)/2 點用較小視窗或鏡像延伸（採鏡像延伸，測試需涵蓋）。
- 實作純 Swift，係數用最小平方解一次算好並快取。

## 5. 次數切分
狀態：`rest / concentric / eccentric`。
- 進入向心：`v > velThreshold` 連續 ≥ `minPhaseSeconds`；進入離心：`v < −velThreshold` 同理。
- 階段結束：`|v| ≤ velThreshold` 或速度反向。
- 階段**兩端**都回推／延伸到 `v` 跨過 0 的那一點（讓位移與時間完整）。實作上以位置的局部極值定位這個零點（向心＝底→頂，離心＝頂→底）：極值附近速度≈0、雜訊會左右正負號，用位置轉折點比直接找速度零點穩，否則每下會少算 1–2 幀、MV 被高估（見 DECISIONS D-027）。
- 有效向心：位移 ≥ `minROM`。無效的向心段忽略。
- 一下（rep）的組成：
  - `startsWithConcentric == true`（硬舉）：有效向心 + 之後緊接的離心（若有）。
  - `false`（蹲、臥推）：有效向心 + 之前緊接的離心（若有）。
- 片段最後一個離心若沒有對應的向心（例如放下槓鈴），不算一下。

## 6. 指標
向心段為 `[s, e]`（索引），時間長 `T = t[e] − t[s]`。
| 指標 | 定義 |
|---|---|
| 向心平均速度 MV | `(p[e] − p[s]) / T` |
| 峰值速度 PV | `max(v[s...e])`（有多個相同最大值時取最早索引，供 MPV 找煞車點用） |
| 動作幅度 ROM | `p[e] − p[s]`（顯示為 cm） |
| MPV | 推進段 `[s, k]` 的平均速度，`k` = PV 之後第一個 `a < −9.81` 的索引的前一點；若沒有這樣的點，`k = e`。`MPV = (p[k] − p[s]) / (t[k] − t[s])` |
| 離心平均速度 | `|p[e'] − p[s']| / T'`（取絕對值） |
| 離心峰值速度 | `max(|v|)` in 離心段 |
| 離心/向心比 | `離心 MV / 向心 MV × 100%`（衍生值，不落在 `RepMetrics`，由顯示層以 `eccentric.meanVelocity / concentric.meanVelocity` 計算） |
| 間隔 restAfter | 下一下的第一個階段起點 − 這一下的最後一個階段終點 |
| 相對第 1 下 | `(MV_n − MV_1) / MV_1 × 100%`（顯示「↓11%」） |

組別摘要：
| 指標 | 定義 |
|---|---|
| repCount | 有效次數 |
| meanVelocity | 各下 MV 的平均 |
| peakVelocity | 各下 PV 的最大值 |
| meanROM | 各下 ROM 的平均 |
| velocityLoss | `(MV_first − MV_last) / MV_first × 100%`；只有 1 下時為 nil |

> 對照 Arcus 範例：MV 0.28/0.25/0.24 → 平均 0.257（顯示 0.26）、速度損失 14.3%。可作為測試案例的參考數量級。

> **相位時間（v2，M7 Q11）**：`PhaseMetrics` 另帶該相位的起訖時間 `startTime`/`endTime`（秒，相對片段起點，取自 `Phase`），供結果頁速度曲線標示每一下的範圍（R1、R2…）。純加法、不改上表任何數值；為讓升版前的舊紀錄經升級重算補上此欄位，`analysisVersion` 由 1 升為 2（欄位為 optional，舊 JSON 解碼不受影響）。見 DECISIONS D-031。

## 7. 預設參數（`AnalysisParameters`）
| 參數 | 預設 | 說明 |
|---|---|---|
| minConfidence | 0.30 | 追蹤信心下限 |
| maxGapFrames | 6 | 可內插的最大連續缺漏 |
| sgWindowSeconds | 0.15 | SG 視窗長度（60fps → 9 點） |
| sgOrder | 3 | SG 多項式階數 |
| velThreshold | 0.05 m/s | 階段判斷門檻 |
| minPhaseSeconds | 0.10 s | 階段最短持續時間 |
| minROM | 0.10 m | 有效向心最小位移（M4 五動作統一 0.10 m，回答 Q8；各動作覆寫待 M7 實測，見 D-027） |
| maxCenterJumpFactor | 0.5 | 追蹤：單幀中心跳動上限 = 此值 × 槓片直徑（px），超過視為缺漏（見 skill plate-tracking §3、DECISIONS D-022） |
| maxAreaGrowthFactor | 2.0 | 追蹤：追蹤框面積相對初始框成長上限倍數，超過視為缺漏 |
| minAreaShrinkFactor | 0.5 | 追蹤：追蹤框面積相對初始框縮小下限倍數，低於視為缺漏 |

> 追蹤三項門檻影響「追蹤」階段（原始 `TrackSample` 產生之前）；改值需重新追蹤，與 `analysisVersion`（從既有樣本重算）無關，不觸發升版。

## 8. 測試要求
- 合成訊號：用已知速度函數（例如半正弦向心 + 半正弦離心 × 3 下 + 停頓）產生位置，加上高斯雜訊 σ = 2 px，換回正規化座標後跑完整管線，斷言：次數正確、MV 誤差 < 0.02 m/s、ROM 誤差 < 1 cm。
- 邊界：只有 1 下、沒有任何動作、片段從動作中間開始、最後放下槓鈴、缺漏剛好 = maxGapFrames 與 +1、30fps 與 60fps、變動影格率時間戳。
- 端對端：測試中用 `AVAssetWriter` 產生「圓盤上下移動」的合成影片（已知軌跡），跑 Vision 追蹤 + 全管線。見 skill `accuracy-check`。
- 追蹤準確度（M2 實測）：中等速度每幀中心誤差 < 2 px、平均 < 1.5 px；直/橫拍一致 < 2 px。`VNTrackObjectRequest` 框中心即使靜止也有 ~0.9 px 固有偏差，故平均門檻為 1.5 px 而非 1 px（見 DECISIONS D-023）。真實影片準確度待實機驗證（OPEN_QUESTIONS Q10）。

## 9. 半自動貼齊槓片（ML 偵測，V1.1，建議圈；見 DECISIONS D-033）
只產生**建議的初始圈**，不改追蹤與校正的任何數值路徑；偵測失敗退回純手動。**原生輪廓偵測法已試過並退掉**（結構性失敗，見 D-033）。

**流程**：起點幀 → `VNCoreMLRequest`（YOLOv8n→Core ML，`BarbellDetector.mlpackage`，`imageCropAndScaleOption = .scaleFit` 對齊 YOLO letterbox）偵測所有槓片框 → 使用者**點一下**選中框住點擊的那片 → 由框換算成 `PlateSelection`。

**座標**：偵測框為 **Vision 正規化**（0–1、原點左下、轉正後影像；handler 帶 `frame.orientation`），與 `PlateSelection`/追蹤同慣例。`DetectedPlate.centerX/Y = box.midX/midY`。

**框 → 直徑（Stage 3）**：
```
diameterPx = height × heightPx        // 取框「高」（垂直投影）
```
槓片是「直徑 45cm、厚度沿槓桿（水平）」的圓盤。側拍（相機大致水平、槓桿大致水平）時，**框高（垂直投影）＝真直徑**，與相機左右偏角、槓片厚度都無關：
- 相機左右偏角 θ → **框寬**被透視壓縮成 `D·cosθ`（想由寬還原需知道未知的 θ，`D=寬/cosθ`，不可行）；框高不變＝D。
- 厚片（如 200kg）→ 斜角時**框寬**還會被厚度側面灌水（`D·cosθ + 厚度·sinθ`）；框高仍是乾淨的 D。
故取框高、繞過角度未知數。**已知殘差**：相機俯拍/槓桿明顯傾斜 → 框高失準（這時真直徑是橢圓長軸）；YOLO 框邊與槓片外緣若有系統性差異 → 可加校正係數（需真實畫面校準，暫未加）。
緩解：**建議圈預設顯示且可拖曳/縮放**，最終比例尺仍以使用者調整後的圈為準（D-006）；更通用可改用框內**橢圓長軸**擬合（列後續）。

**挑選**：點擊（正規化、原點左下）落在框內（`|x−cx| ≤ w/2 且 |y−cy| ≤ h/2`）者中，取框中心離點擊最近的那個；都不落在任何框內 → 回 nil（退回手動）。多槓片（架上收納片）由使用者的手指消歧義。

**不影響 `analysisVersion`**：偵測只產生建議 `PlateSelection`，不碰 §1–§6 公式或 `PlateTracker`/`Calibrator` 數值；維持 2。

**測試**：`DetectedPlate` 幾何（框內/外/邊界、重疊取最近、空、換算）在 VBTCore 純測；偵測載入+推論 smoke 測試在 VBTVision；真實影片座標/方向無翻轉以 `TestVideos/`（gitignore 時跳過）驗。真實影片偵測準確度（含臥推/斜角盲區）需實機目視（D-033、D-019）。
