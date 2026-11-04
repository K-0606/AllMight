---
name: velocity-analysis
description: Implement and test barbell kinematics in VBTCore — calibration, gap filling, resampling, Savitzky-Golay smoothing and derivatives, rep segmentation, and VBT metrics (MV, MPV, peak velocity, ROM, velocity loss). Use when writing or changing any of these, or when rep counts or velocities look wrong.
---

# 速度與次數分析（VBTCore）

**公式與參數唯一來源：`docs/ALGORITHMS.md`。** 這份 skill 講做法，不重複定義；兩者衝突時以 ALGORITHMS 為準並回報衝突。

## 1. 實作順序（每步先寫測試）
1. `SignalGenerator`（測試用）：給定每下的向心/離心時間、幅度、停頓 → 產生位置序列與真實 MV/PV/ROM。半正弦速度剖面：`v(t) = Vpeak · sin(π t / T)`，位移 = `2 Vpeak T / π`，MV = `2 Vpeak / π`。
2. `Calibrator`：正規化座標 → 公尺（§1–2）。
3. `GapFiller` + `Resampler`（§3）。
4. `SavitzkyGolay`（§4）。
5. `RepSegmenter`（§5）。
6. `MetricsCalculator`（§6）。
7. `KinematicsPipeline`：串起 2–6，輸入 `[TrackSample]` + `PlateSelection` + `VideoGeometry` + `Exercise` + `AnalysisParameters`，輸出 `SetAnalysis`。

## 2. Savitzky-Golay 實作提示
- 對視窗 `m = −h…h` 建 Vandermonde 矩陣 `A[m][k] = m^k`（k = 0…order），係數 `C = (AᵀA)⁻¹Aᵀ`。
  - 平滑：`C` 第 0 列；一階導數：第 1 列 ÷ dt；二階導數：第 2 列 × 2 ÷ dt²。
- 小矩陣直接用高斯消去法解，不需要 LAPACK。係數依 (h, order) 快取。
- 驗證：對多項式 `p(t)=a+bt+ct²`（階數 ≤ order）平滑後應完全不變，一階導數應等於 `b+2ct`（容差 1e-9）。這是第一個要寫的測試。
- 邊界用鏡像延伸：`x[−i] = 2x[0] − x[i]`（保持斜率連續）。

## 3. 次數切分提示
- 先把速度序列轉成「符號序列」：`+1`（> 門檻）、`−1`（< −門檻）、`0`。
- 合併短於 `minPhaseSeconds` 的片段到相鄰片段（去抖動）。
- 每個 ±1 片段的起點往前找到 `v` 變號（或最接近 0）的位置，終點往後找，讓位移完整。
- 依 `Exercise.startsWithConcentric` 配對向心與離心（§5）。
- 輸出 `[Phase]` 與 `[Rep]`，保留索引方便畫圖。

## 4. 常見問題排查
| 症狀 | 可能原因 |
|---|---|
| 次數多算 | 門檻太低、雜訊未平滑、沒有 minROM 過濾、槓鈴放下時的晃動 |
| 次數少算 | 兩下之間沒停頓且速度沒回到門檻內 → 確認「速度直接反向」也會切階段 |
| 速度整體偏小或偏大固定比例 | 比例尺錯：圓圈直徑換算、轉正前後寬高搞混 |
| 速度方向相反 | 用了左上原點座標（UIKit），應該是 Vision 左下原點 |
| 峰值速度異常大 | 追蹤跳點沒被過濾；二階導數視窗太小 |
| MPV = MV | 正常情況（慢速、重負荷時推進段 = 整個向心）；輕負荷時 MPV 應 ≤ MV |

## 5. 測試清單（全部要有）
ALGORITHMS §8 所列情境 + 以上 Savitzky-Golay 多項式測試 + 每個指標一個手算小例子。
