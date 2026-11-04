---
name: accuracy-check
description: Measure end-to-end tracking and velocity accuracy using a generated synthetic moving-plate video with known ground truth, plus optional real test videos in TestVideos/. Use after changing tracking, calibration, smoothing or segmentation, or when asked how accurate the analysis is.
---

# 準確度檢查

## 1. 合成影片產生器（測試工具，放 `Tests/VBTVisionTests/Support/SyntheticVideo.swift`）
用 `AVAssetWriter` + `AVAssetWriterInputPixelBufferAdaptor` 產生 H.264 影片：
- 尺寸 1080×1920（直式），fps 60（可參數化 30/60），背景深灰帶一點雜訊紋理。
- 畫一個槓片：外圈亮色圓環 + 內圈不同顏色 + 中心孔（讓追蹤器有特徵可抓），直徑 300 px。
- 軌跡：依 `SignalGenerator` 的位置序列（公尺）換成像素，比例尺 = 0.45 m / 300 px。
- 選項：`rotate90: Bool` → 以橫向像素寫入並設定 `writerInput.transform = CGAffineTransform(rotationAngle: .pi/2)` 模擬 iPhone 直拍。
- 選項：`occlusion: ClosedRange<Double>?` → 那段時間用矩形擋住槓片，測遺失判斷。
- 回傳影片 URL 與真實值（每幀中心像素、每下 MV/PV/ROM）。
繪圖用 CoreGraphics 畫進 `CVPixelBuffer`（BGRA）。

## 2. 要跑的檢查
| 測試 | 通過標準 |
|---|---|
| 追蹤中心誤差（無擋） | 每幀 < 2 px，平均 < 1 px |
| 直拍版與橫拍版結果一致 | 中心座標差 < 1 px |
| 3 下全管線 | 次數 = 3；每下 MV 誤差 < 0.02 m/s；ROM 誤差 < 1 cm |
| 30 fps 版 | 次數正確；MV 誤差 < 0.03 m/s |
| 擋住 0.5 秒 | 丟出 `trackingLost`，時間在擋住區間內 |

## 3. 真實影片（選用）
- 影片放 `TestVideos/`，旁邊放同名 `.json`：
  ```json
  { "exercise": "sumoDeadlift", "loadKg": 200, "plateDiameterCm": 45,
    "trimStart": 35.0, "trimEnd": 65.0,
    "selection": { "centerX": 0.48, "centerY": 0.31, "diameterPx": 310 },
    "expected": { "reps": 3, "meanVelocities": [0.28, 0.25, 0.24] } }
  ```
  `expected` 由使用者提供（來自其他 VBT 裝置或人工判讀），沒有就只檢查次數。
- 測試在檔案不存在時跳過。結果輸出成表格：影片名、預期/實際次數、每下 MV 誤差。

## 4. 回報格式
```
準確度檢查（合成影片 60fps / 30fps、真實影片 N 段）
- 追蹤誤差：平均 0.6 px、最大 1.4 px
- MV 誤差：最大 0.011 m/s
- 次數：全部正確 / 錯誤清單
- 與上次比較：…
```
結果有退步時，不要調整通過標準，先回報原因。
