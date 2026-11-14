import SwiftUI

/// 拍攝建議（PRD §3.10）：靜態說明頁，教使用者怎麼拍出能準確分析的側拍影片。
/// 從「訓練」分頁的「拍攝建議」入口以 sheet 開啟，純說明、無互動流程。
struct FilmingTipsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Space.l) {
                        Card(title: "架設手機", systemImage: "iphone.gen3") {
                            TipRow(symbol: "camera.aperture", text: "手機固定在腳架上，從側面拍，鏡頭正對槓片、與槓片面垂直。")
                            TipRow(symbol: "arrow.up.and.down", text: "手機高度大約與槓片同高，避免由上往下或由下往上拍。")
                        }

                        Card(title: "讓槓片入鏡", systemImage: "scope") {
                            TipRow(symbol: "rectangle.dashed", text: "整組動作中，槓片從最低到最高都要留在畫面內。")
                            TipRow(symbol: "eye.slash", text: "槓片不要被身體、手臂或深蹲架擋住。")
                        }

                        Card(title: "錄影設定", systemImage: "gearshape") {
                            TipRow(symbol: "speedometer", text: "用 60fps 錄影，速度計算會更準。")
                            TipRow(symbol: "sun.max", text: "光線充足，槓片與背景對比清楚。")
                            TipRow(symbol: "xmark.circle", text: "不要用慢動作，也不要在錄影中縮放畫面。")
                        }
                    }
                    .padding(Theme.Space.l)
                }
            }
            .navigationTitle("拍攝建議")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

/// 拍攝建議頁的一列：左側 SF Symbol，右側說明文字。
private struct TipRow: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    FilmingTipsView()
        .preferredColorScheme(.dark)
}
