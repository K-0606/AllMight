import SwiftUI

/// 指標說明（結果頁 ⓘ，PRD §3.8）。文字說明該指標的意義，不含錯誤代碼或道歉語（見 ui-text 規則）。
struct MetricInfo: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    static let rom = MetricInfo(
        id: "rom",
        title: "動作幅度（ROM）",
        description: "槓鈴在一下裡垂直移動的距離（公分），由追蹤到的槓片位置換算而來。數值為各下的平均。"
    )
    static let peakVelocity = MetricInfo(
        id: "peakVelocity",
        title: "峰值速度",
        description: "向心（出力）階段達到的最快瞬間速度。這裡顯示整組各下的最大值。"
    )
    static let meanVelocity = MetricInfo(
        id: "meanVelocity",
        title: "平均速度（MV）",
        description: "向心階段整段的平均速度，是 VBT 常用來判斷負荷強度與疲勞的指標。這裡顯示各下的平均。"
    )
    static let velocityLoss = MetricInfo(
        id: "velocityLoss",
        title: "速度損失",
        description: "最後一下相對第一下的向心平均速度下降比例，用來判斷這一組累積的疲勞程度。"
    )
    static let mpv = MetricInfo(
        id: "mpv",
        title: "平均推進速度（MPV）",
        description: "只計算槓鈴還在加速（推進）那一段的平均速度，排除末端減速；在中低負荷時比 MV 更具代表性。"
    )
}

/// 指標說明彈窗。
struct MetricInfoSheet: View {
    let info: MetricInfo

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Text(info.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Color.textPrimary)
            Text(info.description)
                .font(.body)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.xl)
        .background(Theme.Color.background)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            MetricInfoSheet(info: .meanVelocity)
                .preferredColorScheme(.dark)
        }
}
