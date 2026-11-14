import SwiftUI

/// 疊在起點幀上的槓片對齊圓圈：外圈 + 中心十字 + 四個外緣刻度，方便把圓圈貼齊槓片外緣（見 PRD §3.5、DECISIONS D-029）。
///
/// 只負責畫；位置與縮放由 `PlateSelectView` 的手勢更新 `PlateSelectModel`。
/// 圓圈同時兼作比例尺（`scale = 槓片公分 / 圓圈像素直徑`），貼齊外緣與否直接影響速度/幅度準確度，
/// 故加深色描邊暈環（在亮/暗槓片上都看得清）與外緣刻度，強化「貼齊外緣」的視覺引導。
struct PlateCircleOverlay: View {
    /// 圓心（view 點數，原點左上）。
    let center: CGPoint
    /// 圓圈直徑（view 點數）。
    let diameter: Double

    private let radius: Double

    init(center: CGPoint, diameter: Double) {
        self.center = center
        self.diameter = diameter
        self.radius = diameter / 2
    }

    var body: some View {
        ZStack {
            // 深色暈環：讓薄荷綠外圈在任何底色的槓片上都看得清楚。
            Circle()
                .stroke(Color.black.opacity(0.5), lineWidth: 5)
                .frame(width: diameter, height: diameter)

            Circle()
                .stroke(Theme.Color.accent, lineWidth: 3)
                .frame(width: diameter, height: diameter)

            // 四個外緣刻度（上下左右），把視線引導到「圓圈應貼齊的外緣」。
            ForEach(0..<4, id: \.self) { i in
                EdgeTick()
                    .rotationEffect(.degrees(Double(i) * 90))
                    .offset(edgeOffset(index: i))
            }

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

    /// 把刻度放到圓圈四個外緣點（上、右、下、左）。
    private func edgeOffset(index: Int) -> CGSize {
        switch index {
        case 0: return CGSize(width: 0, height: -radius)
        case 1: return CGSize(width: radius, height: 0)
        case 2: return CGSize(width: 0, height: radius)
        default: return CGSize(width: -radius, height: 0)
        }
    }
}

/// 單一外緣刻度：一小段跨在圓圈外緣上的短線。
private struct EdgeTick: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Color.accent)
            .frame(width: 2, height: 10)
    }
}

#Preview {
    ZStack {
        Theme.Color.background.ignoresSafeArea()
        PlateCircleOverlay(center: CGPoint(x: 160, y: 160), diameter: 180)
    }
    .preferredColorScheme(.dark)
}
