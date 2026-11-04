---
name: video-pipeline
description: How to inspect, orient and decode video frames with AVFoundation for analysis (VideoInspector, FrameReader, orientation, slow-motion and frame-rate checks, trimming, thumbnails). Use when working on video import, trimming, or frame reading in VBTVision.
---

# 影片讀取管線（AVFoundation）

## 1. VideoInspector
```swift
let asset = AVURLAsset(url: url)
guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw AnalysisError.videoUnreadable }
let (size, transform, fps, duration) = try await (
    track.load(.naturalSize), track.load(.preferredTransform),
    track.load(.nominalFrameRate), asset.load(.duration))
```
- **轉正尺寸**：`CGRect(origin: .zero, size: size).applying(transform)` 取絕對值寬高。
- **方向**：由 transform 的旋轉角 `atan2(transform.b, transform.a)` 對應：
  | 角度 | `CGImagePropertyOrientation` |
  |---|---|
  | 0° | `.up` |
  | 90° | `.right`（iPhone 直拍最常見） |
  | 180° | `.down` |
  | −90° / 270° | `.left` |
  有鏡像（前鏡頭）時 `a*d - b*c < 0`，對應 `*Mirrored`；寫測試涵蓋四個角度。
- **慢動作偵測**：iPhone 慢動作從相簿匯出時常是帶時間變速的組合，或 `nominalFrameRate > 120`。判斷：`fps > 120` 或 asset 有多段 `segments` 的時間對應不是 1:1（`track.load(.segments)` 檢查 `timeMapping.source.duration != timeMapping.target.duration`）。處理方式依 OPEN_QUESTIONS Q3。PhotosPicker 交出來的慢動作檔案格式會因 iOS 版本與選取設定而不同，**這個判斷要用使用者的真實慢動作影片實測**，不要只靠推論。
- fps < 24 → `frameRateTooLow`。

## 2. FrameReader
```swift
let reader = try AVAssetReader(asset: asset)
reader.timeRange = CMTimeRange(start: CMTime(seconds: trimStart, preferredTimescale: 600),
                               end:   CMTime(seconds: trimEnd,   preferredTimescale: 600))
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
])
output.alwaysCopiesSampleData = false
reader.add(output)
guard reader.startReading() else { throw AnalysisError.videoUnreadable }
while let sample = output.copyNextSampleBuffer() {
    try Task.checkCancellation()
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
    let t = CMSampleBufferGetPresentationTimeStamp(sample).seconds - trimStart
    // 交給 tracker；不要把 pixelBuffer 存起來
}
if reader.status == .failed { throw AnalysisError.videoUnreadable }
```
- **一次一幀**，處理完就釋放；用 `autoreleasepool {}` 包每一幀的處理。
- 時間戳用 presentation time，不要用「索引 × 1/fps」（手機影片可能是變動影格率）。
- 取消時呼叫 `reader.cancelReading()`。
- 整個 reader 生命週期留在 `AnalysisPipeline` actor 內，不跨 actor 傳 `CMSampleBuffer` / `CVPixelBuffer`。

## 3. 剪輯畫面用的縮圖與起點幀
```swift
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true          // 縮圖自動轉正
gen.maximumSize = CGSize(width: 200, height: 200)
for await result in gen.images(for: times) { ... } // iOS 16+ async API
```
- 點選槓片畫面用的起點幀：`requestedTimeToleranceBefore/After = .zero` 取精確幀，`maximumSize` 用原尺寸。
- **縮圖已轉正，而 FrameReader 的 pixelBuffer 沒有轉正**，靠 orientation 參數交給 Vision。兩者座標要一致：點擊座標都以「轉正後影像」換算成 Vision 正規化座標。

## 4. 測試
- 用 `AVAssetWriter` 在暫存資料夾產生測試影片（見 skill `accuracy-check`），可設定 `writerInput.transform` 模擬直拍 90°。
- 驗證：轉正尺寸、方向對應、片段範圍內幀數 ≈ (trimEnd − trimStart) × fps（±1）、時間戳遞增。
