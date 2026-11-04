# 隱私與檔案規則（永遠套用）

- 不加任何網路請求、分析或廣告 SDK、崩潰回報服務。
- 選影片只用 `PhotosPicker`；不要請求 `PHPhotoLibrary` 完整權限。要加任何 Info.plist 權限描述前先問。
- App 的檔案放 `Application Support/`（Videos/、Samples/），不要放 Documents（避免出現在「檔案」App）。目錄不存在就建立。
- 所有檔案路徑透過 `FileStore` 取得，不在別處組路徑。資料庫只存檔名，不存絕對路徑（App 容器路徑會變）。
- 刪除紀錄時同步刪影片與樣本檔；寫測試驗證。
- 不要把使用者的測試影片 commit 進 git。
