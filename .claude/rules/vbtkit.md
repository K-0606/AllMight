---
paths:
  - "Packages/VBTKit/**"
---

# VBTKit 規則

- `VBTCore`：只能 import `Foundation`、`Accelerate`。不能有 UIKit、SwiftUI、AVFoundation、Vision、CoreGraphics 型別出現在 API。
- `VBTVision`：可用 AVFoundation、Vision、CoreMedia、CoreVideo、CoreGraphics；不能 import UIKit、SwiftUI。
- 依賴方向 `VBTVision → VBTCore`，不可反向。
- 所有公式依照 `docs/ALGORITHMS.md`；程式裡在對應函式上方註明章節（例如 `// ALGORITHMS §6 MPV`）。
- 所有可調整數值放進 `AnalysisParameters`，不寫死。
- 座標系一律 Vision 正規化（原點左下、已轉正）。任何座標轉換函式要有單元測試。
- 函式保持純粹：相同輸入相同輸出，不讀時間、不讀檔案（`FrameReader` 除外）。
- 每個公開函式至少一個測試；演算法改動要附合成訊號測試。
- package 必須能在 macOS 上 `swift test`（平台 `.macOS(.v14)`）。不要使用只有 iOS 才有的 API；不得已時用 `#if os(iOS)` 並在 macOS 測試中略過，同時告知使用者。
