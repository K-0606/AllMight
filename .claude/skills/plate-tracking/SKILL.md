---
name: plate-tracking
description: Track the barbell plate across frames with Vision VNTrackObjectRequest, convert tap and circle coordinates to Vision normalized space, and detect tracking loss. Use when working on PlateSelectView, PlateTracker, or tracking accuracy.
---

# 槓片追蹤（Vision）

## 1. 座標（最容易出錯）
- Vision 正規化座標：0–1，**原點左下**，以「轉正後影像」為準（只要 perform 時傳對 orientation）。
- 點選畫面（SwiftUI，原點左上）→ Vision：
  ```swift
  // imageRect = 影像在 view 中實際顯示的區域（aspect fit 扣掉 letterbox）
  let xN = (tap.x - imageRect.minX) / imageRect.width
  let yN = 1 - (tap.y - imageRect.minY) / imageRect.height
  ```
- 圓圈直徑（view 點數）→ 影像像素：`diameterPx = diameterPt / imageRect.width × orientedWidthPx`。
- 初始框：以圓心為中心、邊長 = 直徑的正方形，轉成正規化 `CGRect`（寬除以 width，高除以 height），夾在 0–1 內。
- 這些轉換寫成純函式放 VBTCore 或 VBTVision，並寫測試（含 letterbox、直式、橫式）。

## 2. 追蹤迴圈
```swift
let handler = VNSequenceRequestHandler()
let request = VNTrackObjectRequest(detectedObjectObservation:
    VNDetectedObjectObservation(boundingBox: initialRect))
request.trackingLevel = .accurate

for frame in frames {
    try handler.perform([request], on: frame.pixelBuffer, orientation: frame.orientation)
    guard let obs = request.results?.first as? VNDetectedObjectObservation else { /* 記為缺漏 */ continue }
    samples.append(TrackSample(time: frame.time, x: obs.boundingBox.midX, y: obs.boundingBox.midY,
                               confidence: obs.confidence))
    request.inputObservation = obs          // 每一幀都要把上一幀結果餵回去
}
request.isLastFrame = true                  // 結束時釋放追蹤器
try? handler.perform([request], on: lastBuffer, orientation: orientation)
```
- 整段只用**同一個** `VNSequenceRequestHandler` 與同一個 request。
- 第一幀就是使用者選取的那一幀；第一個樣本直接用使用者的圓心（信心 1.0）。
- `confidence < minConfidence` 視為缺漏；缺漏規則見 ALGORITHMS §3。
- 追蹤框大小會漂移：**只用中心點**，比例尺用使用者圓圈（DECISIONS D-006）。

## 3. 遺失與漂移的偵測
- 連續缺漏 > `maxGapFrames` → `trackingLost(atTime:)`。
- 單幀中心跳動 > 0.5 × 槓片直徑 → 視為缺漏（不合物理的瞬移）。
- 框面積相對初始框變化 > 2 倍或 < 0.5 倍 → 視為缺漏，並把 `inputObservation` 重設為「上一個好位置 + 初始大小」再繼續。

## 4. 準確度注意
- 槓片被身體擋住（硬舉起槓、臥推側拍）是最常見的失敗；不要用演算法硬猜，回報遺失讓使用者重選。
- 若真實影片準確度不夠，可提出（**先問**）的改進：
  1. 每 N 幀用 `VNDetectContoursRequest` 在追蹤框附近找圓形輪廓重新定位
  2. 改追蹤槓鈴末端的槓片中心圓孔
  3. 訓練 CoreML 槓片偵測模型（Create ML Object Detection）

## 5. 測試
- 合成影片：純色背景上的圓盤（有對比的圓環圖樣）以已知軌跡上下移動 → 每幀中心誤差 < 2 px。
- 直拍（transform 90°）版本的合成影片，結果座標應與橫拍版一致。
- Vision 在 macOS 也能跑，這些測試放 VBTVisionTests 用 `swift test` 執行。
