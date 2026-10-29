import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    let exercise: Exercise

    enum Tab: String, CaseIterable, Identifiable {
        case data, guide, history

        var id: String { rawValue }

        var title: String {
            switch self {
            case .data: "數據"
            case .guide: "說明"
            case .history: "歷史"
            }
        }
    }

    @State private var tab: Tab = .data
    @State private var showingEdit = false
    @Environment(WorkoutCoordinator.self) private var coordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeader(exercise: exercise)
                Picker("分頁", selection: $tab.animation(.tap)) {
                    ForEach(Tab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .data:
                    ExerciseDataTab(exercise: exercise, onOpenSession: open)
                case .guide:
                    ExerciseGuideTab(exercise: exercise)
                case .history:
                    HistoryCard(items: exercise.completedItems) { coordinator.showSummary(of: $0) }
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("編輯動作", systemImage: "pencil") { showingEdit = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("更多")
            }
        }
        .sheet(isPresented: $showingEdit) {
            ExerciseEditView(exercise: exercise)
        }
        #if DEBUG
        // 開發用：-detailTab guide｜history 打開該分頁
        .task {
            if let raw = UserDefaults.standard.string(forKey: "detailTab"), let value = Tab(rawValue: raw) { tab = value }
        }
        #endif
    }

    /// 點紀錄或圖表上的點：打開那次訓練的摘要浮窗（第 3 層不再 push 頁面）
    private func open(_ sessionID: UUID) {
        if let session = exercise.completedItems.lazy.compactMap(\.session).first(where: { $0.id == sessionID }) {
            coordinator.showSummary(of: session)
        }
    }
}

/// 頁首：名稱、分類、tags、器材、上次、近 90 天
private struct DetailHeader: View {
    let exercise: Exercise
    @Environment(StatsCache.self) private var stats

    var body: some View {
        let days = Recency.daysSince(exercise.lastCompletedDate, now: stats.snapshot.now)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(exercise.name).font(.title.bold())
                ForEach(exercise.tags) { Chip(text: $0.title) }
                if exercise.isArchived { Chip(text: "封存") }
            }
            Text("\(exercise.category.fullTitle) · \(exercise.equipment.title)")
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 0) {
                stat(Recency.staleness(days: days).text(days.map(RelativeDay.text) ?? "未練過", normal: Theme.textPrimary), "上次")
                stat(Text("\(exercise.trainingCount(withinDays: 90)) 次"), "近 90 天")
            }
        }
        .card()
    }

    /// value 自己帶顏色：很久沒練是 warning 色加圖示（CHANGE_14 §2），其他主要文字色
    private func stat(_ value: Text, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.footnote).foregroundStyle(Theme.textSecondary)
            value.font(.title3.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HistoryCard: View {
    var items: [SessionExercise]
    var onOpen: (WorkoutSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全部紀錄（\(items.count) 次）").font(.headline).foregroundStyle(Theme.textSecondary)
            if items.isEmpty {
                Text("還沒有紀錄").foregroundStyle(Theme.textSecondary)
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().overlay(Theme.separator) }
                if let session = item.session {
                    Button { onOpen(session) } label: {
                        HistoryLine(item: item, date: session.startedAt).tapRowInset()
                    }
                    .buttonStyle(.tapRow)
                    .tapRowOutset()
                }
            }
        }
        .card()
    }
}

/// 一次訓練一行：日期 · 精簡的組數字；有備註時顯示在下面
private struct HistoryLine: View {
    var item: SessionExercise
    var date: Date
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(date.shortDate)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
                Spacer(minLength: 12)
                Text(item.summary(unit: unit))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
