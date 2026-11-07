import SwiftUI

/// 疊在起點幀上的槓片對齊圓圈：外圈 + 中心十字，方便對齊槓片外緣（見 PRD §3.5）。
///
/// 只負責畫；位置與縮放由 `PlateSelectView` 的手勢更新 `PlateSelectModel`。
struct PlateCircleOverlay: View {
    /// 圓心（view 點數，原點左上）。
    let center: CGPoint
    /// 圓圈直徑（view 點數）。
    let diameter: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Color.accent, lineWidth: 3)
                .frame(width: diameter, height: diameter)

            // 中心十字，幫助對準槓片中心。用兩條在 ZStack 內置中的細長方形，
            // 確保十字正好落在圓心（Path 以 frame 左上為原點，會偏移，故不用）。
            Rectangle()
                .fill(Theme.Color.accent)
                .frame(width: 16, height: 2)
            Rectangle()
                .fill(Theme.Color.accent)
                .frame(width: 2, height: 16)
        }
        .position(center)
        .allowsHitTesting(false)
    }
}
