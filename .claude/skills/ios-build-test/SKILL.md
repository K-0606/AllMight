---
name: ios-build-test
description: Build and test the AllMight iOS app and the VBTKit package with xcodebuild and swift test, and diagnose build errors. Use whenever code changed and needs verifying, or when a build or test fails.
---

# 建置與測試

## 1. 先跑 package 測試（最快）
```bash
swift test --package-path Packages/VBTKit 2>&1 | tail -40
# 只跑某個測試
swift test --package-path Packages/VBTKit --filter RepSegmenterTests
```

## 2. 找可用的模擬器（第一次或建置失敗說找不到 destination 時）
```bash
xcrun simctl list devices available | grep -E "iPhone" | head
```
選一台 iOS 17 以上的 iPhone，把名稱代入下面的 `SIM`。記下來寫進回報，之後沿用。

## 3. App 建置與測試
```bash
SIM="iPhone 17"
xcodebuild -project AllMight.xcodeproj -scheme AllMight \
  -destination "platform=iOS Simulator,name=$SIM" -quiet build 2>&1 | tail -60

xcodebuild -project AllMight.xcodeproj -scheme AllMight \
  -destination "platform=iOS Simulator,name=$SIM" -quiet test 2>&1 | tail -80
```
- 輸出太長時用 `grep -E "error:|warning:|failed|passed"` 過濾。
- 第一次建置會解析本機 package，比較久，timeout 設 10 分鐘。

## 4. 常見錯誤
| 症狀 | 處理 |
|---|---|
| `No such module 'VBTCore'` | App 還沒加入本機 package。不要自己改 .pbxproj，請使用者在 Xcode：File ▸ Add Package Dependencies ▸ Add Local… 選 `Packages/VBTKit`，並把 VBTCore、VBTVision 加到 AllMight target |
| 新檔案沒被編譯 | 確認放在 target 的同步資料夾內；若專案不是同步資料夾，請使用者在 Xcode 加入檔案 |
| Swift 6 並行錯誤（`Sendable`、actor isolation） | 依 `.claude/rules/swift-style.md` 處理，不要用 unsafe 標記消錯 |
| `Unable to find a destination` | 回到步驟 2 換模擬器名稱 |
| 簽章錯誤（實機） | 模擬器不需簽章；實機簽章請使用者在 Xcode 設定 Team |

## 5. 規則
- **不要手動編輯 `.xcodeproj/project.pbxproj`**。需要改專案設定時，列出步驟請使用者在 Xcode 操作。
- 同一錯誤修 3 次失敗 → 停下來回報完整錯誤與已嘗試的方法。
- 回報時附上：跑了哪些指令、通過/失敗數量、新增的警告。
