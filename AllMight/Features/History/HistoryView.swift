import SwiftUI
import SwiftData
import os
import VBTCore

/// 歷史分頁（PRD §3.9）：依日期分組的紀錄列表，左滑刪除（確認後連同影片與樣本檔一起刪），
/// 點進去是同一個結果頁。開啟前若 `analysisVersion` 較舊，用存好的樣本重算並寫回（DECISIONS D-030）。
struct HistoryView: View {
    private static let logger = Logger(subsystem: "com.kun0606.AllMight", category: "History")

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSet.createdAt, order: .reverse) private var sets: [WorkoutSet]
    @State private var pendingDelete: WorkoutSet?
    private let fileStore = FileStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.background.ignoresSafeArea()
                if sets.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("歷史")
            .navigationDestination(for: WorkoutSet.self) { set in
                resultDestination(set)
            }
        }
        .task { recomputeStale() }
    }

    // MARK: - 列表

    private var list: some View {
        List {
            ForEach(groupedSets, id: \.day) { group in
                Section {
                    ForEach(group.items) { set in
                        NavigationLink(value: set) {
                            HistoryRow(set: set)
                        }
                        .listRowBackground(Theme.Color.surface)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDelete = set
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(dayLabel(group.day))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .confirmationDialog(
            "刪除這組紀錄？",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { set in
            Button("刪除", role: .destructive) { delete(set) }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("會連同影片一起刪除，無法復原。")
        }
    }

    private var emptyState: some View {
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

    // MARK: - 結果頁導向

    @ViewBuilder
    private func resultDestination(_ set: WorkoutSet) -> some View {
        // 升級重算在 .task 的 recomputeStale() 已統一處理；此處只解碼呈現。
        if let context = try? ResultContext(set: set, fileStore: fileStore) {
            ResultView(context: context)
        } else {
            ContentUnavailableView("無法開啟這組紀錄", systemImage: "exclamationmark.triangle")
        }
    }

    // MARK: - 分組與動作

    /// 依「當天零點」分組，日期新到舊、組內時間新到舊。
    private var groupedSets: [(day: Date, items: [WorkoutSet])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sets) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).compactMap { day in
            grouped[day].map { (day, $0.sorted { $0.createdAt > $1.createdAt }) }
        }
    }

    private func dayLabel(_ day: Date) -> String {
        day.formatted(.dateTime.year().month().day())
    }

    private func recomputeStale() {
        let store = WorkoutStore(modelContext: modelContext)
        for set in sets {
            do {
                _ = try store.recomputeIfNeeded(set)
            } catch {
                Self.logger.error("升級重算失敗 id=\(set.id, privacy: .public)：\(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func delete(_ set: WorkoutSet) {
        do {
            try WorkoutStore(modelContext: modelContext).delete(set)
        } catch {
            Self.logger.error("刪除失敗 id=\(set.id, privacy: .public)：\(error.localizedDescription, privacy: .public)")
        }
        pendingDelete = nil
    }
}

/// 歷史列表的一列（PRD §3.9）：動作、重量 × 次數、平均速度、時間。
private struct HistoryRow: View {
    let set: WorkoutSet

    var body: some View {
        let summary = set.decodedSummary
        HStack {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(set.exercise?.displayName ?? "")
                    .font(.headline)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("\(Formatters.weightKg(set.loadKg)) × \(summary?.repCount ?? 0)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Theme.Space.xs) {
                Text(Formatters.velocity(summary?.meanVelocity ?? 0))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(set.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .padding(.vertical, Theme.Space.xs)
        // 整列合成一個 VoiceOver 元素，依序讀出動作、重量×次數、平均速度、時間。
        .accessibilityElement(children: .combine)
    }
}

private extension WorkoutSet {
    var decodedSummary: SetSummary? {
        (try? JSONDecoder().decode(SetAnalysis.self, from: analysisData))?.summary
    }

    var exercise: Exercise? {
        Exercise(rawValue: exerciseRaw)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutSet.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let analysisData = (try? JSONEncoder().encode(PreviewData.analysis)) ?? Data()
    for (exercise, load, daysAgo) in [(Exercise.backSquat, 200.0, 0), (.benchPress, 100.0, 0), (.conventionalDeadlift, 180.0, 2)] {
        container.mainContext.insert(WorkoutSet(
            createdAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
            exerciseRaw: exercise.rawValue, loadKg: load, plateDiameterCm: 45, rpe: 8, isWarmup: false,
            videoFileName: "x.mov", trimStart: 0, trimEnd: 6,
            selectionData: Data(), geometryData: Data(), samplesFileName: "x.json", analysisData: analysisData
        ))
    }
    return HistoryView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
