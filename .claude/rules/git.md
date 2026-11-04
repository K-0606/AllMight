# Git 規則（永遠套用）

- 只有使用者要求時才 commit；不要自動 push。
- 一個 commit 對應一個 ROADMAP 小項目，訊息格式：`[M2] PlateTracker：加入遺失判斷`。
- commit 前確認測試通過、沒有把 `TestVideos/`、`DerivedData/`、`*.xcuserstate` 加進去。
- 不要改 git 設定、不要 `--force`、不要 rebase 已推上去的分支。
