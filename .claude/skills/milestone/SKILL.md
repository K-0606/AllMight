---
name: milestone
description: Work through one AllMight roadmap milestone step by step (plan, clarify, test-first implement, verify, update docs). Invoke with a milestone id, e.g. /milestone M2.
disable-model-invocation: true
argument-hint: "[M0-M7]"
---

# 執行里程碑 $ARGUMENTS

1. **讀**：`docs/ROADMAP.md` 中 $ARGUMENTS 的段落、`docs/OPEN_QUESTIONS.md`，以及這個里程碑相關的 PRD / ARCHITECTURE / ALGORITHMS 章節與 skill。
2. **檢查前置**：前面的里程碑是否完成？（M3、M4 可與 M1、M2 平行）未完成就告訴使用者，詢問是否繼續。
3. **列問題**：找出這個里程碑會碰到的 OPEN_QUESTIONS 項目和規格不清楚的地方。有任何一項 → **先問，等回答再開始**。
4. **計畫**：列出要做的小步驟（對應 ROADMAP 的勾選項目）、每步會新增或修改的檔案、驗證方式。等使用者說可以再動手（使用者說「直接做」時可略過等待）。
5. **逐步實作**：每一步依 `.claude/rules/00-workflow.md` 的節奏：測試 → 實作 → `ios-build-test` → 勾選 ROADMAP。
6. **中途發現問題**：停在可編譯狀態，回報並詢問，不要繞過。
7. **收尾**：
   - 跑完整測試（package + App）
   - 演算法相關里程碑跑 `accuracy-check`
   - 呼叫子 Agent `algorithm-reviewer`（動到 VBTKit 時）或 `ios-reviewer`（動到 App 層時）審查，處理它提出的問題
   - 更新 ROADMAP、DECISIONS、OPEN_QUESTIONS
   - 回報：完成項目、測試結果、需要使用者實機驗證的事、下一個里程碑
