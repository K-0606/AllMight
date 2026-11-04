import SwiftUI

/// 首頁：兩個分頁「訓練」與「歷史」。
/// M0 只放入口與空狀態；實際導覽（影片設定、剪輯、結果、歷史內容）在之後的里程碑接上。
struct HomeView: View {
    var body: some View {
        TabView {
            TrainingTab()
                .tabItem {
                    Label("訓練", systemImage: "figure.strengthtraining.traditional")
                }

            HistoryTab()
                .tabItem {
                    Label("歷史", systemImage: "clock.arrow.circlepath")
                }
        }
        .tint(Theme.Color.accent)
    }
}

/// 「訓練」分頁入口：影片分析大卡片與「拍攝建議」次要入口。按鈕的目的地在 M1 接上。
private struct TrainingTab: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.background.ignoresSafeArea()

                VStack(spacing: Theme.Space.l) {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        Image(systemName: "video.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.Color.accent)
                        Text("影片分析")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("匯入已錄好的影片進行分析")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Space.xl)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                    Button {
                        // M1：導向影片設定頁。
                    } label: {
                        Text("拍攝建議")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                    }

                    Spacer()
                }
                .padding(Theme.Space.l)
            }
            .navigationTitle("訓練")
        }
    }
}

/// 「歷史」分頁：M0 顯示空狀態。
private struct HistoryTab: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.background.ignoresSafeArea()

                VStack(spacing: Theme.Space.m) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Text("還沒有紀錄。到「訓練」分頁匯入第一段影片。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.Space.xl)
            }
            .navigationTitle("歷史")
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
