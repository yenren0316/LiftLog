import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name)
    private var exercises: [Exercise]
    @Query private var allSets: [SetRecord]
    /// 統計用：包含封存的動作（封存動作的歷史仍計入近 30 天）
    @Query private var allExercises: [Exercise]
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }) private var endedSessions: [WorkoutSession]

    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator

    @State private var path = NavigationPath()
    @State private var filter: TagFilter = .all
    @State private var planRequest: PlanRequest?
    /// 有進行中的訓練時，按「＋」先問要繼續還是結束
    @State private var pendingPlan: PlanRequest?
    /// 建立菜單後，等 sheet 關掉再展開訓練中畫面
    @State private var startedFromPlan = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ScreenHeader(title: "該練什麼") {
                            CircleIconButton(systemName: "plus") { openPlan(nil) }
                                .accessibilityLabel("建立菜單")
                        }
                        let history = PlanHistory(sessions: endedSessions)
                        NextPlanCard(history: history) { openPlan($0) }
                        ActivityGraph(days: trainingDays)
                        CategoryBarsCard(exercises: allExercises, history: history) { category in
                            withAnimation { proxy.scrollTo(category, anchor: .top) }
                        }
                        TagFilterBar(selection: $filter)

                        let visible = exercises.filter { $0.matches(filter) }
                        let sections = Recency.sections(
                            visible, category: \.category, lastDate: \.lastCompletedDate, name: \.name
                        )
                        if sections.isEmpty {
                            Text("沒有符合的動作").foregroundStyle(Theme.textSecondary).card()
                        }
                        ForEach(sections, id: \.category) { section in
                            CategorySection(
                                category: section.category,
                                exercises: section.items,
                                onShowDetail: { path.append($0) }
                            )
                            .id(section.category)
                        }
                        StalenessLegend()
                    }
                    .padding(16)
                }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
            #if DEBUG
            .navigationDestination(for: DebugDetailRoute.self) { ExerciseDetailView(exercise: $0.exercise) }
            #endif
        }
        .sheet(item: $planRequest, onDismiss: {
            if startedFromPlan {
                startedFromPlan = false
                coordinator.isExpanded = true
            }
        }) { request in
            PlanFlowView(initialAnswers: request.answers) { startedFromPlan = true }
        }
        .confirmationDialog(
            "已經有進行中的訓練",
            isPresented: Binding(get: { pendingPlan != nil }, set: { if !$0 { pendingPlan = nil } }),
            titleVisibility: .visible,
            presenting: pendingPlan
        ) { request in
            Button("繼續目前訓練") { coordinator.isExpanded = true }
            Button("結束並建立新菜單", role: .destructive) {
                if let session = WorkoutActions.activeSession(in: context) {
                    WorkoutActions.finish(session, choice: .deleteIncomplete, in: context)
                }
                planRequest = request
            }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("結束目前的訓練時，沒打勾的組會被刪除。")
        }
        #if DEBUG
        // 開發用：啟動參數 -openExercise 臥推 直接打開記錄頁；-openDetail 臥推 直接打開動作詳情
        .task {
            let defaults = UserDefaults.standard
            if let name = defaults.string(forKey: "openExercise"),
               let exercise = exercises.first(where: { $0.name == name }) {
                path.append(exercise)
            }
            if let name = defaults.string(forKey: "openDetail"),
               let exercise = exercises.first(where: { $0.name == name }) {
                path.append(DebugDetailRoute(exercise: exercise))
            }
            // -openPlan YES 直接打開建立菜單
            if defaults.bool(forKey: "openPlan") { planRequest = PlanRequest() }
        }
        #endif
    }
}

extension HomeView {
    /// 訓練日曆用：每天做了幾個動作（只算已完成的組）
    private var trainingDays: [Date: Int] {
        var exercisesByDay: [Date: Set<PersistentIdentifier>] = [:]
        for set in allSets where set.isCompleted {
            guard let date = set.completedAt, let item = set.sessionExercise else { continue }
            exercisesByDay[Calendar.current.startOfDay(for: date), default: []].insert(item.persistentModelID)
        }
        return exercisesByDay.mapValues(\.count)
    }
}

extension HomeView {
    /// 打開建立菜單；有進行中的訓練時先問
    private func openPlan(_ answers: PlanAnswers?) {
        let request = PlanRequest(answers: answers)
        if WorkoutActions.activeSession(in: context) != nil {
            pendingPlan = request
        } else {
            planRequest = request
        }
    }
}

/// 「下一次建議」：依建立菜單的預設答案，點一下帶著這些答案進入流程
private struct NextPlanCard: View {
    var history: PlanHistory
    var onOpen: (PlanAnswers) -> Void

    var body: some View {
        let answers = PlanDefaults.answers(history)
        let last = PlanDefaults.lastRegionSession(history)
        Button { onOpen(answers) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("下一次建議").font(.headline).foregroundStyle(Theme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(answers.region.title).font(.title.bold())
                        if let last {
                            Text("上次 \(last.date.formatted(.dateTime.month(.defaultDigits).day())) 是\(last.region.title)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Text("\(answers.count) 個動作・\(answers.cardio ? "加跑步機" : "不加跑步機")")
                        .font(.body.weight(.semibold))
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .card()
    }
}

/// 最近 30 天各分類訓練天數，點一下跳到該分類；有氧另外顯示在最下方，不參與長條比例；
/// 下方是近 30 天有「單邊」「爆發」角色的訓練次數
private struct CategoryBarsCard: View {
    var exercises: [Exercise]
    var history: PlanHistory
    var onSelect: (ExerciseCategory) -> Void

    var body: some View {
        let done = exercises.flatMap { ex in
            ex.sessionItems.flatMap { $0.completedSets.compactMap(\.completedAt) }.map { (date: $0, exercise: ex) }
        }
        let counts = Recency.trainingDays(done.map { (date: $0.date, key: $0.exercise.category) })
        let unilateral = history.sessionCount(within: .now) { $0.role == .unilateral }
        let explosive = history.sessionCount(within: .now) { $0.role == .explosive }
        // 沒有動作的分類不顯示；有氧另外放
        let categories = ExerciseCategory.allCases.filter { c in c != .cardio && exercises.contains { $0.category == c } }
        let maxCount = max(categories.compactMap { counts[$0] }.max() ?? 0, 1)

        VStack(alignment: .leading, spacing: 12) {
            Text("最近 30 天")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
            ForEach(categories) { category in
                let count = counts[category] ?? 0
                Button { onSelect(category) } label: {
                    HStack(spacing: 12) {
                        Text(category.title)
                            .font(.body.weight(.semibold))
                            .frame(width: 96, alignment: .leading)
                        ThinBar(fraction: Double(count) / Double(maxCount), color: color(for: count))
                        Text("\(count) 天")
                            .font(.body.weight(.bold).monospacedDigit())
                            .foregroundStyle(color(for: count))
                            .frame(width: 52, alignment: .trailing)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            Divider().overlay(Theme.separator)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                roleCount("單邊", unilateral)
                Text("・").foregroundStyle(Theme.textSecondary)
                roleCount("爆發", explosive)
                Spacer()
                if exercises.contains(where: { $0.category == .cardio }) {
                    let cardio = counts[.cardio] ?? 0
                    Button { onSelect(.cardio) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("有氧").font(.body.weight(.semibold))
                            Text(String(cardio))
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(color(for: cardio))
                            Text("天").font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private func roleCount(_ title: String, _ count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).font(.body.weight(.semibold))
            Text(String(count))
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color(for: count))
            Text("次").font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: Theme.danger
        case 1...2: Theme.warning
        default: Theme.done
        }
    }
}

private struct CategorySection: View {
    var category: ExerciseCategory
    var exercises: [Exercise]
    var onShowDetail: (Exercise) -> Void

    @State private var showUntrained = false

    var body: some View {
        // 未練過的不排最前面，收在最後一列「還沒練過（N）」
        let trained = exercises.filter { $0.lastCompletedDate != nil }
        let untrained = exercises.filter { $0.lastCompletedDate == nil }
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(category.title).font(.title2.bold())
                if let subtitle = category.subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.bottom, 8)

            ForEach(Array(trained.enumerated()), id: \.element.id) { index, exercise in
                if index > 0 { Divider().overlay(Theme.separator) }
                row(exercise)
            }

            if !untrained.isEmpty {
                if !trained.isEmpty { Divider().overlay(Theme.separator) }
                Button { withAnimation { showUntrained.toggle() } } label: {
                    HStack {
                        Text("還沒練過（\(untrained.count)）")
                            .font(.headline)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(showUntrained ? 0 : -90))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if showUntrained {
                    ForEach(untrained) { exercise in
                        Divider().overlay(Theme.separator)
                        row(exercise)
                    }
                }
            }
        }
        .card()
    }

    private func row(_ exercise: Exercise) -> some View {
        Button { onShowDetail(exercise) } label: {
            ExerciseRow(exercise: exercise)
        }
        .buttonStyle(.plain)
    }
}

struct ExerciseRow: View {
    var exercise: Exercise
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg

    var body: some View {
        let last = exercise.lastSummary(unit: unit)
        let days = Recency.daysSince(exercise.lastCompletedDate)
        let staleness = Recency.staleness(days: days)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    ForEach(exercise.tags) { Chip(text: $0.title) }
                }
                if let last {
                    Text("\(last.date.shortDate) · \(last.text)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                if let days {
                    Text(days == 0 ? "今天" : String(days))
                        .font(.title2.weight(.bold).monospacedDigit())
                    if days > 0 {
                        Text("天前").font(.caption)
                    }
                } else {
                    Text("未練過").font(.headline)
                }
            }
            .foregroundStyle(staleness.color)
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}

private struct StalenessLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            item(Theme.done, "60 天內")
            item(Theme.warning, "超過 60 天")
            item(Theme.danger, "超過 180 天")
        }
        .font(.subheadline)
        .foregroundStyle(Theme.textSecondary)
        .frame(maxWidth: .infinity)
        .card(padding: 14)
    }

    private func item(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

#if DEBUG
private struct DebugDetailRoute: Hashable {
    var exercise: Exercise
}
#endif
