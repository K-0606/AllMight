# 開始使用：用 Claude Code 開發 AllMight

## 這包檔案是什麼

| 檔案 | 給誰看 | 作用 |
|---|---|---|
| `CLAUDE.md` | Claude（每次開工自動讀） | 專案總說明、技術限制、指令、工作方式 |
| `docs/PRD.md` | 你和 Claude | 功能規格：每個畫面、欄位、文字、錯誤情況 |
| `docs/FLOW.md` | 你和 Claude | 使用者流程、分析管線、狀態機（Mermaid 圖） |
| `docs/ARCHITECTURE.md` | Claude | 模組分層、資料模型、並行模型 |
| `docs/ALGORITHMS.md` | Claude | 速度、次數、指標的公式與參數（唯一來源） |
| `docs/ROADMAP.md` | 你和 Claude | M0–M7 里程碑、勾選進度、驗收標準 |
| `docs/DECISIONS.md` | 你和 Claude | 做過的決定與原因 |
| `docs/OPEN_QUESTIONS.md` | **你** | 還沒決定的事，Claude 碰到會停下來問 |
| `.claude/rules/*.md` | Claude（自動載入） | 必須遵守的規則；有 `paths` 的只在改到對應檔案時載入 |
| `.claude/skills/*/SKILL.md` | Claude（需要時自動載入） | 特定工作的做法（建置、影片、追蹤、演算法、畫面、準確度） |
| `.claude/skills/milestone` | 你用 `/milestone M2` 呼叫 | 照標準流程做一個里程碑 |
| `.claude/agents/*.md` | Claude 呼叫的子 Agent | 演算法審查、iOS 程式審查 |
| `.claude/settings.json` | Claude Code | 允許自動執行的指令；禁止直接改 Xcode 專案檔 |

## 一次性設定（約 15 分鐘）

1. **安裝工具**：Xcode 16 以上（App Store）、開過一次並裝好 iOS 模擬器；安裝 Claude Code（依官方文件 https://docs.claude.com/en/docs/claude-code/overview ）。
2. **在 Xcode 建專案**：File ▸ New ▸ Project ▸ iOS ▸ App
   - Product Name：`AllMight`（或你決定的名稱，記得同步改 CLAUDE.md）
   - Interface：SwiftUI　Language：Swift　Testing System：Swift Testing　Storage：None（SwiftData 由 Claude 依架構文件設定）
   - 存到一個新資料夾，例如 `~/Developer/AllMight`
   - Target ▸ General ▸ Minimum Deployments 設 iOS 17.0；Build Settings ▸ Swift Language Version 設 Swift 6
3. **放入這包文件**：把壓縮檔裡 `AllMight/` 底下的全部內容（含隱藏的 `.claude` 資料夾與 `.gitignore`）複製到專案根目錄，也就是和 `AllMight.xcodeproj` 同一層。
4. **建立 git**（建議，方便回復）：在專案資料夾執行 `git init && git add -A && git commit -m "初始專案與 Agent 文件"`。
5. **先回答 `docs/OPEN_QUESTIONS.md`**：至少 Q1、Q2、Q3、Q7。直接編輯檔案，或開工時告訴 Claude。
6. **準備測試影片**（M2 之後需要）：5–10 段側拍訓練影片放進 `TestVideos/`（已在 .gitignore，不會被 commit）。

## 開始開發

在專案資料夾打開終端機，執行 `claude`，第一句可以這樣說：

```
請讀 CLAUDE.md 和 docs/ 裡的文件，確認你理解專案。
列出你對規格還有疑問的地方，然後執行 /milestone M0。
```

之後每個里程碑：`/milestone M1`、`/milestone M2`…。M3、M4 是純演算法，可以在 M1 之前先做。

## 需要你親自做的事

- 在 Xcode 裡加本機 Swift Package 依賴（M0，Claude 會給步驟）。Claude 被設定成**不直接改 .xcodeproj**，避免專案檔損壞。
- 在實機上測試追蹤與速度（M2、M7），並把結果告訴 Claude。
- 回答 Claude 停下來問的問題。規則要求它不確定就問，不要猜，所以它會比一般情況更常停下來。

## 調整這套文件

- 規格改了 → 改 `docs/PRD.md`，並在 DECISIONS 加一筆。
- 想讓 Claude 更常或更少停下來問 → 改 `.claude/rules/00-workflow.md` 的清單。
- 某類錯誤一直發生 → 把正確做法寫進對應 skill 的「常見問題」表。
