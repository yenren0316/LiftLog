import SwiftUI
import SwiftData

/// 第 1 層「今天」：只回答「下一次該練什麼？」——「下一次」卡、訓練日曆、近 30 天各分類組數。
/// 統計都從 StatsCache 讀，body 裡不掃描訓練紀錄
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Environment(WorkoutLauncher.self) private var launcher
    @Environment(StatsCache.self) private var stats

    var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.todayPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScreenHeader(title: "今天")
                    NextPlanCard(answers: stats.snapshot.nextPlan, suggestedMain: stats.snapshot.suggestedMain) {
                        launcher.requestPlan($0, context: context)
                    }
                    TrainingCalendar(days: stats.snapshot.days, now: stats.snapshot.now,
                                     emptyText: "還沒有訓練紀錄。點上面的「下一次」建立第一份菜單。") {
                        coordinator.showingTrainingStatus = true
                    }
                    RecentSetsCard(sets: stats.snapshot.recentSets) { coordinator.todayPath.append($0) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ExerciseCategory.self) { CategoryTodoList(category: $0) }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            #if DEBUG
            // 開發用：-todayCategory core 打開該分類的待練清單
            .task {
                if let raw = UserDefaults.standard.string(forKey: "todayCategory"), let category = ExerciseCategory(rawValue: raw) {
                    coordinator.todayPath.append(category)
                }
            }
            #endif
        }
    }
}

/// 「下一次：ME 上肢｜建議主項：臥推」：建立菜單的預設答案，點一下帶著這些答案進入建立菜單
private struct NextPlanCard: View {
    var answers: PlanAnswers
    var suggestedMain: String?
    var onOpen: (PlanAnswers) -> Void

    var body: some View {
        Button { onOpen(answers) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("下一次").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(answers.dayType.title).font(.title.bold())
                        if let suggestedMain {
                            Text("建議主項：\(suggestedMain)")
                                .font(.headline)
                                .foregroundStyle(Theme.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    Text("\(answers.count) 個動作・\(answers.cardio ? "加跑步機" : "不加跑步機")")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        // 整張卡都能點，按下時換成按壓色（CHANGE_10 §4）
        .buttonStyle(.tapCard)
    }
}

/// 近 30 天 9 個分類的組數長條，點一下到第 2 層「分類待練清單」
private struct RecentSetsCard: View {
    var sets: [ExerciseCategory: Int]
    var onSelect: (ExerciseCategory) -> Void

    var body: some View {
        let maxCount = max(sets.values.max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("近 30 天").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("組數").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 2)
            ForEach(ExerciseCategory.allCases) { category in
                let count = sets[category] ?? 0
                Button { onSelect(category) } label: {
                    HStack(spacing: 10) {
                        Text(category.title)
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 84, alignment: .leading)
                        ThinBar(fraction: Double(count) / Double(maxCount), color: color(count))
                        Text("\(count)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(color(count))
                            .frame(width: 32, alignment: .trailing)
                    }
                    .frame(minHeight: 24)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.tapRow)
                .tapRowOutset()
            }
        }
        .card(padding: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recentSetsCard")
    }

    /// 0 組紅色、未滿 10 組黃色、10 組以上綠色
    private func color(_ count: Int) -> Color {
        count == 0 ? Theme.danger : count < RecentVolume.enoughSets ? Theme.warning : Theme.done
    }
}

/// 第 2 層「分類待練清單」：該分類未封存的動作，依多久沒練排序（沒練過的排最前、標「新」）
struct CategoryTodoList: View {
    let category: ExerciseCategory

    @Environment(WorkoutCoordinator.self) private var coordinator
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(StatsCache.self) private var stats
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg

    var body: some View {
        let list = exercises.filter { $0.category == category }
        let sorted = Recency.sortedByNeglect(list, lastDate: { stats.snapshot.exercises[$0.id]?.lastDate }, name: \.name,
                                             untrainedLast: false)
        List {
            if sorted.isEmpty {
                Text("這個分類沒有動作").foregroundStyle(Theme.textSecondary).listRowBackground(Theme.card)
            }
            ForEach(sorted) { exercise in
                TapListRow { coordinator.todayPath.append(exercise) } label: {
                    TodoRow(exercise: exercise, stat: stats.snapshot.exercises[exercise.id], now: stats.snapshot.now, unit: unit)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 名稱、標籤、「新」；「上次 日期・N 天前」；上次的精簡紀錄
private struct TodoRow: View {
    var exercise: Exercise
    var stat: StatsSnapshot.ExerciseStat?
    /// 統計快照的「現在」（CHANGE_11 §2）
    var now: Date
    var unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(exercise.name).font(.body.weight(.semibold)).lineLimit(1)
                ForEach(exercise.tags) { Chip(text: $0.title) }
                if stat?.lastDate == nil { AccentChip(text: "新") }
            }
            if let date = stat?.lastDate {
                let days = Recency.daysSince(date, now: now)
                Text("上次 \(date.shortDate)・\(RelativeDay.text(since: date, now: now) ?? "")")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Recency.staleness(days: days).color)
                Text(SetFormat.compact(stat?.lastSets ?? [], logType: exercise.logType, unit: unit))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            } else {
                Text("還沒練過").font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
