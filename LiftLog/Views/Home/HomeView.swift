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
    /// 往下滑時分頁列隱藏，右下角改出現「＋」
    @State private var tabBarHidden = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ScreenHeader(title: "該練什麼")
                        let history = PlanHistory(sessions: endedSessions)
                        NextPlanCard(history: history, exercises: exercises.map(PlanExercise.init)) { openPlan($0) }
                        ActivityGraph(days: trainingDays)
                        MainLiftsCard(exercises: exercises.filter { $0.tags.contains(.main) }, history: history) {
                            path.append($0)
                        }
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
                .hidesTabBarOnScroll($tabBarHidden)
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
        // 放在 NavigationStack 外面才會排在訓練中橫條的上方；進入下一頁時 tabBarHidden 會恢復成 false
        .overlay(alignment: .bottomTrailing) {
            if tabBarHidden {
                FloatingActionButton(systemName: "plus") { openPlan(nil) }
                    .accessibilityLabel("建立菜單")
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
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
        // 深層連結 liftlog://new：用預設答案打開建立菜單（App 剛啟動時也要接得到，所以 initial）
        .onChange(of: coordinator.planRequestedByLink, initial: true) { _, requested in
            guard requested else { return }
            coordinator.planRequestedByLink = false
            if planRequest == nil { openPlan(nil) }
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

/// 「下一次：ME 上肢｜建議主項：臥推」：建立菜單的預設答案，點一下帶著這些答案進入建立菜單
private struct NextPlanCard: View {
    var history: PlanHistory
    var exercises: [PlanExercise]
    var onOpen: (PlanAnswers) -> Void

    var body: some View {
        let answers = PlanDefaults.answers(history)
        let main = PlanRanking.candidates(for: Slot.main(for: answers.dayType), dayType: answers.dayType,
                                          exercises: exercises, history: history).items.first
        Button { onOpen(answers) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("下一次").font(.headline).foregroundStyle(Theme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(answers.dayType.title).font(.title.bold())
                        if let main {
                            Text("建議主項：\(main.exercise.name)")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
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
        .buttonStyle(.pressable)
        .card()
    }
}

/// 「主項紀錄」：每個「主」動作最近一次 ME 紀錄（重量 × 次數、估算 1RM、日期）和上一次的差距；點一下開動作詳情
private struct MainLiftsCard: View {
    var exercises: [Exercise]
    var history: PlanHistory
    var onShowDetail: (Exercise) -> Void

    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg

    var body: some View {
        let order = ExerciseCategory.allCases
        let sorted = exercises.sorted {
            (order.firstIndex(of: $0.category)!, $0.meRotation ?? .max, $0.name)
                < (order.firstIndex(of: $1.category)!, $1.meRotation ?? .max, $1.name)
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("主項紀錄")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 6)
            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, exercise in
                if index > 0 { Divider().overlay(Theme.separator) }
                Button { onShowDetail(exercise) } label: {
                    row(exercise, MainLiftSummary(logs: history.logs(for: exercise.id)))
                }
                .buttonStyle(.pressable)
            }
        }
        .card()
    }

    private func row(_ exercise: Exercise, _ summary: MainLiftSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.body.weight(.semibold))
                if let record = summary.latest {
                    Text("\(unit.formatWithUnit(kg: record.weightKg)) × \(record.reps)・\(record.date.formatted(.dateTime.month(.defaultDigits).day()))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            if let record = summary.latest {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("估 1RM \(unit.formatWithUnit(kg: record.estimated1RM))")
                        .font(.body.weight(.bold).monospacedDigit())
                    if let change = summary.change {
                        Text(changeText(change))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(change > 0 ? Theme.done : change < 0 ? Theme.danger : Theme.textSecondary)
                    }
                }
            } else {
                Text("尚無紀錄").font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
    }

    /// 「比上次 +3.3 kg」
    private func changeText(_ change: Double) -> String {
        let value = unit.format(kg: abs(change))
        return change == 0 || value == "0" ? "和上次一樣" : "比上次 \(change > 0 ? "+" : "−")\(value) \(unit.symbol)"
    }
}

/// 最近 30 天各重訓分類完成的組數，點一下跳到該分類；下面是推：拉組數比（拉比推少時用警示色），
/// 再下面是近 30 天有「單邊」「爆發」動作的訓練次數和有氧天數
private struct CategoryBarsCard: View {
    var exercises: [Exercise]
    var history: PlanHistory
    var onSelect: (ExerciseCategory) -> Void

    var body: some View {
        let volume = RecentVolume(history: history)
        let unilateral = history.sessionCount(within: .now) { $0.tags.contains(.unilateral) }
        let explosive = history.sessionCount(within: .now) { $0.tags.contains(.explosive) }
        let cardioDays = Recency.trainingDays(
            exercises.filter { $0.category == .cardio }.flatMap { ex in
                ex.sessionItems.flatMap { $0.completedSets.compactMap(\.completedAt) }.map { (date: $0, key: 0) }
            }
        )[0] ?? 0
        // 沒有動作的分類不顯示；有氧另外放
        let categories = ExerciseCategory.allCases.filter { c in c != .cardio && exercises.contains { $0.category == c } }
        let maxCount = max(categories.map { volume[$0] }.max() ?? 0, 1)

        VStack(alignment: .leading, spacing: 12) {
            Text("最近 30 天")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
            ForEach(categories) { category in
                let count = volume[category]
                Button { onSelect(category) } label: {
                    HStack(spacing: 12) {
                        Text(category.title)
                            .font(.body.weight(.semibold))
                            .frame(width: 96, alignment: .leading)
                        ThinBar(fraction: Double(count) / Double(maxCount), color: color(forSets: count))
                        Text("\(count) 組")
                            .font(.body.weight(.bold).monospacedDigit())
                            .foregroundStyle(color(forSets: count))
                            .frame(width: 60, alignment: .trailing)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
            }
            Divider().overlay(Theme.separator)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("推：拉").font(.body.weight(.semibold))
                Text("\(volume.push)：\(volume.pull)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(volume.pullIsShort ? Theme.warning : Theme.done)
                Text("組").font(.subheadline).foregroundStyle(Theme.textSecondary)
                if volume.pullIsShort {
                    Text("拉比推少").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.warning)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                roleCount("單邊", unilateral)
                Text("・").foregroundStyle(Theme.textSecondary)
                roleCount("爆發", explosive)
                Spacer()
                if exercises.contains(where: { $0.category == .cardio }) {
                    Button { onSelect(.cardio) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("有氧").font(.body.weight(.semibold))
                            Text(String(cardioDays))
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(color(forCount: cardioDays))
                            Text("天").font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .buttonStyle(.pressable)
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
                .foregroundStyle(color(forCount: count))
            Text("次").font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
    }

    /// 組數：0 組紅色、未滿 10 組黃色、10 組以上綠色
    private func color(forSets count: Int) -> Color {
        count == 0 ? Theme.danger : count < RecentVolume.enoughSets ? Theme.warning : Theme.done
    }

    /// 次數、天數：0 紅色、1–2 黃色、3 以上綠色
    private func color(forCount count: Int) -> Color {
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
                Button { withAnimation(.tap) { showUntrained.toggle() } } label: {
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
                .buttonStyle(.pressable)
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
        .buttonStyle(.pressable)
    }
}

struct ExerciseRow: View {
    var exercise: Exercise
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg

    var body: some View {
        let last = exercise.homeSummary(unit: unit)
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
