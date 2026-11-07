# 架構

## 1. 分層

```
┌────────────────────────────────────────────┐
│ AllMight (App target)                      │
│  Features/  SwiftUI View + @Observable VM  │
│  Persistence/  SwiftData @Model、檔案存放  │
│  DesignSystem/  色彩、字體、共用元件       │
└───────────────┬────────────────────────────┘
                │ import VBTVision, VBTCore
┌───────────────▼────────────────────────────┐
│ VBTVision  影片 → TrackSample[]            │
│  VideoInspector  FrameReader  Orientation  │
│  PlateTracker  AnalysisPipeline            │
└───────────────┬────────────────────────────┘
                │ import VBTCore
┌───────────────▼────────────────────────────┐
│ VBTCore  純 Swift 計算（可在 macOS 測試）  │
│  Calibrator Resampler SavitzkyGolay        │
│  RepSegmenter MetricsCalculator  Models    │
└────────────────────────────────────────────┘
```

- `VBTCore` 只能 import `Foundation`（必要時 `Accelerate`）。
- `VBTVision` 可 import `AVFoundation`、`Vision`、`CoreMedia`、`CoreVideo`、`CoreGraphics`，**不得 import UIKit / SwiftUI**。
- Package 平台：`.iOS(.v17), .macOS(.v14)`，讓 `swift test` 能在 Mac 上跑。

## 2. 主要型別（VBTCore）

```swift
public enum Exercise: String, Codable, CaseIterable, Sendable {
    case conventionalDeadlift, sumoDeadlift, backSquat, frontSquat, benchPress
    public var startsWithConcentric: Bool { /* 硬舉 true，其餘 false */ }
}

public struct TrackSample: Codable, Sendable {      // 追蹤原始輸出
    public var time: Double          // 秒，相對片段起點
    public var x: Double, y: Double  // Vision 正規化座標（0–1，原點左下，已轉正方向）
    public var confidence: Float
}

public struct PlateSelection: Codable, Sendable {
    public var centerX: Double, centerY: Double   // Vision 正規化座標
    public var diameterPx: Double                 // 轉正後影像的像素
}

public struct VideoGeometry: Codable, Sendable {
    public var widthPx: Int, heightPx: Int        // 轉正後尺寸
    public var nominalFPS: Double
}

public enum PhaseKind: String, Codable, Sendable { case concentric, eccentric, pause }
public struct Phase: Codable, Sendable { kind; startIndex; endIndex; startTime; endTime }

public struct RepMetrics: Codable, Sendable {
    public var index: Int
    public var concentric: PhaseMetrics
    public var eccentric: PhaseMetrics?
    public var mpv: Double
    public var restAfter: Double?                 // 與下一下的間隔
    public var dropFromFirst: Double?             // 相對第 1 下 MV 的變化（負值為下降）
}
public struct PhaseMetrics: Codable, Sendable { duration; meanVelocity; peakVelocity; displacement }

public struct SetSummary: Codable, Sendable { repCount; meanROM; peakVelocity; meanVelocity; velocityLoss }

public struct SetAnalysis: Codable, Sendable {
    public var analysisVersion: Int               // 演算法版本，改公式就 +1
    public var parameters: AnalysisParameters
    public var reps: [RepMetrics]
    public var summary: SetSummary
    public var series: KinematicSeries            // 等間隔的時間、位置、速度（給圖表用）
}
```

定義與公式以 `ALGORITHMS.md` 為準。

## 3. VBTVision

| 型別 | 責任 |
|---|---|
| `VideoInspector` | 讀時長、fps、轉正尺寸、方向、是否慢動作；回傳 `VideoInfo` 或錯誤 |
| `FrameReader` | 拉取式 `next() throws -> Frame?`（非 `AsyncThrowingStream`，見 D-021），Frame = `CVPixelBuffer` + 時間 + 方向。只讀片段範圍、8-bit 輸出 |
| `PlateTracker` | 包住 `VNTrackObjectRequest`；`track(frame) -> TrackSample?`；遺失判斷 |
| `TrackingRunner` | `actor`。串 `FrameReader → PlateTracker` 產生 `[TrackSample]` 與 `TrackingRun`（含 `lostAtTime`）；`os.Logger` 追蹤 log。M4 `AnalysisPipeline` 的追蹤段（見 D-025） |
| `AnalysisPipeline` | `actor`。串起 Reader → Tracker → VBTCore；`AsyncStream<AnalysisProgress>` 回報；支援取消 |

做法見 skill `video-pipeline`、`plate-tracking`。

## 4. App 層

### 4.1 Features
```
Features/
  Home/            HomeView（TabView）
  Setup/           VideoSetupView, VideoSetupModel
  Trim/            TrimView, TimelineStrip, TrimModel
  PlateSelect/     PlateSelectView, PlateCircleOverlay
  Analysis/        AnalysisProgressView, AnalysisModel
  RPE/             RPEPickerSheet
  Result/          ResultView, MetricTiles, RepList, VelocityChart
  History/         HistoryView
  Tips/            FilmingTipsView
```
- ViewModel 用 `@Observable` + `@MainActor`。重運算交給 `AnalysisPipeline` actor。
- 導覽：每個分頁一個 `NavigationStack(path:)`，路由用 `enum Route: Hashable`。

### 4.2 資料儲存
```swift
@Model final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var exerciseRaw: String
    var loadKg: Double
    var plateDiameterCm: Double
    var rpe: Double?          // nil = 跳過
    var isWarmup: Bool
    var videoFileName: String // Application Support/Videos/
    var trimStart: Double
    var trimEnd: Double
    var selectionData: Data   // PlateSelection JSON
    var geometryData: Data    // VideoGeometry JSON
    var samplesFileName: String  // Application Support/Samples/<id>.json（TrackSample[]）
    var analysisData: Data    // SetAnalysis JSON
}
```
- 原始 `TrackSample[]` 另存檔，因此改重量/RPE 或演算法升級時**不用重新追蹤**，只要重跑 VBTCore。
- 刪除 `WorkoutSet` 時一併刪除影片與樣本檔（`FileStore` 負責）。
- 讀到 `analysisVersion` 比目前舊的資料 → 用樣本重算並寫回。

## 5. 並行模型
- Swift 6 嚴格並行。`AnalysisPipeline` 是 `actor`；Vision 與 AVFoundation 物件只在該 actor 內建立與使用，不跨 actor 傳遞。
- 對外只傳 `Sendable` 值型別（`TrackSample`、`AnalysisProgress`、`SetAnalysis`）。
- 取消：`Task` 被取消時每幀檢查 `Task.checkCancellation()`，並呼叫 `reader.cancelReading()`。

## 6. 錯誤
```swift
public enum AnalysisError: Error, Sendable, Equatable {
    case videoUnreadable, unsupportedSlowMotion, frameRateTooLow(Double)
    case videoTooShort(seconds: Double), videoTooLong(seconds: Double)   // PRD §3.3 長度限制（D-015）
    case trackingLost(atTime: Double), noRepsDetected, cancelled
}
```
App 層把每個錯誤對應成 PRD 裡的使用者文字。
