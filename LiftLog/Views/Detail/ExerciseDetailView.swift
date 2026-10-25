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
    @State private var openSession: WorkoutSession?

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
                    HistoryCard(exercise: exercise, items: exercise.completedItems)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編輯") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ExerciseEditView(exercise: exercise)
        }
        .navigationDestination(item: $openSession) { SessionDetailView(session: $0) }
    }

    /// 點紀錄或圖表上的點，打開那次訓練
    private func open(_ sessionID: UUID) {
        openSession = exercise.completedItems.lazy.compactMap(\.session).first { $0.id == sessionID }
    }
}

/// 頁首：名稱、分類、tags、器材、上次、近 90 天、開始或加入訓練
private struct DetailHeader: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil }) private var active: [WorkoutSession]

    var body: some View {
        let days = Recency.daysSince(exercise.lastCompletedDate)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(exercise.name).font(.title.bold())
                ForEach(exercise.tags) { Chip(text: $0.title) }
                if exercise.isArchived { Chip(text: "封存") }
            }
            Text("\(exercise.category.fullTitle) · \(exercise.equipment.title)")
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 0) {
                stat(days.map { $0 == 0 ? "今天" : "\($0) 天前" } ?? "未練過", "上次",
                     color: Recency.staleness(days: days).color)
                stat("\(exercise.trainingCount(withinDays: 90)) 次", "近 90 天", color: Theme.accent)
            }

            Button(action: startOrJoin) {
                Label(active.isEmpty ? "用這個動作開始訓練" : "加入目前訓練",
                      systemImage: active.isEmpty ? "play.fill" : "plus")
                    .font(.headline)
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.accent, in: .capsule)
            }
            .buttonStyle(.pressable)
        }
        .card()
    }

    private func stat(_ value: String, _ title: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.footnote).foregroundStyle(Theme.textSecondary)
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startOrJoin() {
        if let session = active.first {
            _ = WorkoutActions.add(exercise, to: session, in: context)
            coordinator.isExpanded = true
        } else {
            coordinator.requestStart([exercise], context: context)
        }
    }
}

private struct HistoryCard: View {
    var exercise: Exercise
    var items: [SessionExercise]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全部紀錄（\(items.count) 次）").font(.headline).foregroundStyle(Theme.textSecondary)
            if items.isEmpty {
                Text("還沒有紀錄").foregroundStyle(Theme.textSecondary)
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().overlay(Theme.separator) }
                if let session = item.session {
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        HistoryLine(item: item, date: session.startedAt).contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
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
        let hasMax = item.completedSets.contains { $0.kind == .max }
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(date.shortDate)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
                Spacer(minLength: 12)
                Text(item.summary(unit: unit))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(hasMax ? Theme.warning : Theme.textPrimary)
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
