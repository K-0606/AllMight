# AllMight — 槓鈴速度分析 iOS App

> 工作名稱 AllMight，正式名稱待定（見 docs/OPEN_QUESTIONS.md）。

## 這個專案在做什麼

使用者從相簿選一段重量訓練影片（側面拍攝），剪出動作片段，點選槓片，App 逐幀追蹤槓片、換算成公尺，算出每一下的速度指標（平均速度 MV、MPV、峰值速度、動作幅度、速度損失），顯示在結果頁並存在手機本機。這類訓練方法叫 VBT（Velocity-Based Training）。

**MVP 只做「影片匯入分析」。** 骨架與關節角度、疊圖重播匯出、即時相機、1RM/LVP 都不在 MVP，不要主動實作，需要時先問。

## 技術限制（不可自行更改）

- iOS 17.0 以上，iPhone 直式為主。
- **只用 Apple 原生框架**：SwiftUI、Observation、Vision、AVFoundation、PhotosUI、Accelerate、Swift Charts、SwiftData。**不加任何第三方套件**（SPM、CocoaPods 都不行）。若你認為非加不可，停下來說明理由並詢問。
- 介面文字：繁體中文（台灣用語）。
- 資料：只存本機，沒有帳號、沒有後端、沒有網路請求、沒有分析追蹤 SDK。
- Swift 6 語言模式、嚴格並行檢查。

## 專案結構

```
AllMight/                     App target：SwiftUI 畫面、ViewModel、SwiftData 模型
  App/  Features/<功能>/  DesignSystem/  Persistence/  Resources/
Packages/VBTKit/              本機 Swift Package（所有可測試的邏輯）
  Sources/VBTCore/            純計算，不 import UIKit/SwiftUI/AVFoundation/Vision
  Sources/VBTVision/          影片解碼、方向處理、Vision 追蹤
  Tests/VBTCoreTests/  Tests/VBTVisionTests/
docs/                         規格文件（先讀這裡）
.claude/rules/ skills/ agents/
```

依賴方向：`App → VBTVision → VBTCore`。VBTCore 不得反向依賴。

## 開工前必讀

| 要做的事 | 先讀 |
|---|---|
| 任何工作 | `docs/ROADMAP.md`（目前在哪個里程碑）、`docs/OPEN_QUESTIONS.md` |
| 功能、畫面、文字 | `docs/PRD.md`、`docs/FLOW.md` |
| 模組、資料模型、並行 | `docs/ARCHITECTURE.md` |
| 速度、次數、指標 | `docs/ALGORITHMS.md`（公式與參數的唯一來源） |
| 為什麼這樣設計 | `docs/DECISIONS.md` |

## 常用指令

```bash
# 演算法測試（最快，在 Mac 上跑）
swift test --package-path Packages/VBTKit

# App 建置與測試（模擬器名稱先用 xcrun simctl list devices available 確認）
xcodebuild -project AllMight.xcodeproj -scheme AllMight \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build
xcodebuild -project AllMight.xcodeproj -scheme AllMight \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet test
```

細節見 skill `ios-build-test`。

## 工作方式（最重要）

1. **不確定就問，不要猜。** 規格沒寫、文件互相矛盾、需要改技術限制、需要動到範圍外的功能時，停下來列出問題和你建議的選項，等使用者回答。做到一半發現問題也一樣，先停在可編譯的狀態再問。
2. 一次只做一個里程碑裡的一個小步驟；每步結束都要能編譯、測試通過。
3. 演算法先寫測試（合成訊號已知答案），再寫實作。
4. 改了公式或參數 → 同步更新 `docs/ALGORITHMS.md`；做了設計取捨 → 在 `docs/DECISIONS.md` 加一筆；問題得到回答 → 從 `docs/OPEN_QUESTIONS.md` 移到 DECISIONS。
5. 完成一個步驟：勾選 `docs/ROADMAP.md` 的項目，回報「做了什麼、怎麼驗證、還剩什麼」。
6. 不要宣稱完成卻沒跑過建置和測試。無法執行時明講。
7. 追蹤準確度無法只靠模擬器判斷：涉及實機或真實影片的驗證，請使用者在 iPhone 上測並回報。

詳細規則在 `.claude/rules/`，各類工作的做法在 `.claude/skills/`。
