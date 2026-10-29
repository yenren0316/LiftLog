import SwiftUI
import SwiftData

/// 打開建立菜單；answers 為 nil 時用預設答案；backfill 有值時是補登（建立已結束的訓練，預設的日期和時間）
struct PlanRequest: Identifiable {
    let id = UUID()
    var answers: PlanAnswers?
    var backfill: DateInterval?
}

/// 建立菜單（CHANGE_15 §2：一個畫面，取代「三個問題 → 選動作」兩步）。
/// 最上面是日型（旁邊的 Menu 換成其他三個），下面一列是動作數和跑步機，中間每一格一列（角色、建議的動作、原因、處方），
/// 點一格用 Menu 換候選；最下面固定「開始訓練」，照建議的話打開就能直接開始。
/// 預設值、格子、建議和候選都是原本的函式（PlanDefaults、PlanRanking、SlotAdvice），狀態在 PlanMenu。
/// 補登也用這個畫面：最上面多一張日期和時間的卡片，主要按鈕是「補登這次訓練」
struct PlanSheet: View {
    var request: PlanRequest

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutLauncher.self) private var launcher
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }) private var endedSessions: [WorkoutSession]

    /// 打開時建立一次快照（PlanMenu 裡的紀錄和動作），畫面開著時不會變
    @State private var menu: PlanMenu?
    // 補登的日期、開始和結束時間
    @State private var day = Date.now
    @State private var start = Date.now
    @State private var end = Date.now

    private var isBackfill: Bool { request.backfill != nil }

    /// 補登的時間；結束沒有晚於開始時為 nil
    private var backfillInterval: DateInterval? {
        let s = SessionTimeEdit.combine(day: day, time: start), e = SessionTimeEdit.combine(day: day, time: end)
        return e > s ? DateInterval(start: s, end: e) : nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if let menu {
                    PlanMenuContent(menu: Binding(get: { menu }, set: { self.menu = $0 }), timeCard: isBackfill ? timeCard : nil,
                                    primaryTitle: isBackfill ? "補登這次訓練" : "開始訓練",
                                    isEnabled: !isBackfill || backfillInterval != nil,
                                    onStart: startPlan, onFree: startFree)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .screenBackground()
            .navigationTitle(isBackfill ? "補登訓練" : "建立菜單")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左上角是系統的關閉按鈕，也可以往下拖關閉
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .accessibilityIdentifier("closePlan")
                }
            }
        }
        .launchConfirmation(launcher, origin: .plan, context: context)
        .task {
            guard menu == nil else { return }
            var answers = request.answers
            #if DEBUG
            // 開發用：-planAnswers deUpper,2,1 指定日型、動作數、跑步機
            let parts = UserDefaults.standard.string(forKey: "planAnswers")?.split(separator: ",") ?? []
            if parts.count == 3, let dayType = DayType(rawValue: String(parts[0])), let count = Int(parts[1]) {
                answers = PlanAnswers(dayType: dayType, count: count, cardio: parts[2] == "1")
            }
            #endif
            if let backfill = request.backfill {
                day = backfill.start
                start = backfill.start
                end = backfill.end
            }
            menu = PlanMenu(answers: answers, exercises: allExercises.map { PlanExercise($0) },
                            history: PlanHistory(sessions: endedSessions))
        }
    }

    /// 補登：日期、開始時間、結束時間（結束必須晚於開始）
    private var timeCard: AnyView {
        AnyView(VStack(alignment: .leading, spacing: 12) {
            timeRow("日期") { DatePicker("日期", selection: $day, in: ...Date.now, displayedComponents: .date) }
            timeRow("開始時間") { DatePicker("開始時間", selection: $start, displayedComponents: .hourAndMinute) }
            timeRow("結束時間") { DatePicker("結束時間", selection: $end, displayedComponents: .hourAndMinute) }
            if backfillInterval == nil {
                Text.warning("結束時間必須晚於開始時間").font(.footnote)
            }
            Text("補登的訓練是已經結束的訓練：沒有休息計時、即時動態，也不會影響進行中的訓練。")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .card(padding: 16))
    }

    private func timeRow(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary)
            Spacer()
            picker().labelsHidden()
        }
    }

    /// 「開始訓練」／「補登這次訓練」：依格子的順序，每個動作的角色就是格子的角色
    private func startPlan() {
        guard let menu, !isBackfill || backfillInterval != nil, let request = WorkoutLauncher.Request.plan(menu.selection, exercises: allExercises,
                                                                    dayType: menu.answers.dayType,
                                                                    backfill: isBackfill ? backfillInterval : nil)
        else { return }
        launcher.start(request, context: context)
    }

    /// 「不照建議，自由選動作」：建立一次沒有日型的訓練，直接打開新增動作
    private func startFree() {
        guard !isBackfill || backfillInterval != nil else { return }
        launcher.start(.init(openAdd: true, backfill: isBackfill ? backfillInterval : nil, origin: .plan), context: context)
    }
}

/// 建立菜單的內容：日型、動作數和跑步機、每一格、自由選動作；最下面固定主要按鈕。
/// 換日型、換候選、改動作數時 selection 觸覺（CHANGE_15 §4；打開時不震）
private struct PlanMenuContent: View {
    @Binding var menu: PlanMenu
    var timeCard: AnyView?
    var primaryTitle: String
    var isEnabled: Bool
    var onStart: () -> Void
    var onFree: () -> Void

    var body: some View {
        let states = menu.states
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let timeCard { timeCard }
                VStack(alignment: .leading, spacing: 14) {
                    dayTypeRow
                    HStack(spacing: 12) {
                        Picker("動作數", selection: Binding(get: { menu.answers.count },
                                                          set: { count in withAnimation(.tap) { menu.setCount(count) } })) {
                            ForEach(PlanAnswers.countOptions, id: \.self) { Text("\($0) 個").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                        .accessibilityIdentifier("planCount")
                        Toggle("跑步機 \(Prescription.cardioMinutes) 分鐘",
                               isOn: Binding(get: { menu.answers.cardio }, set: { on in withAnimation(.tap) { menu.setCardio(on) } }))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .accessibilityIdentifier("planCardio")
                    }
                }
                .card(padding: 16)

                VStack(spacing: 0) {
                    ForEach(Array(states.enumerated()), id: \.element.slot) { index, state in
                        if index > 0 { Divider().overlay(Theme.separator) }
                        SlotRow(state: state, logs: state.selected.map { menu.history.logs(for: $0.id) } ?? [], index: index) { id in
                            withAnimation(.tap) { menu.pick(id, for: state.slot) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.separator.opacity(0.6)))

                Button("不照建議，自由選動作", action: onFree)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.pressable)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .padding(16)
            .animation(.tap, value: states.map(\.slot))
        }
        // 主要按鈕固定在最下面；捲到下面的內容由系統的邊緣效果淡出（iOS 26 的 safeAreaBar）
        .safeAreaBar(edge: .bottom) {
            PrimaryButton(title: primaryTitle, isEnabled: isEnabled && states.contains { $0.selected != nil }, action: onStart)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .accessibilityIdentifier("planStart")
        }
        .sensoryFeedback(.selection, trigger: menu.answers.dayType)
        .sensoryFeedback(.selection, trigger: menu.answers.count)
        .sensoryFeedback(.selection, trigger: menu.picks)
    }

    /// 大字的日型，旁邊的 Menu 換成其他三個日型（換了全部格子重新計算）
    private var dayTypeRow: some View {
        HStack(alignment: .center) {
            Text(menu.answers.dayType.title)
                .font(.largeTitle.bold())
                .accessibilityIdentifier("planDayType")
            Spacer()
            Menu {
                ForEach(DayType.allCases.filter { $0 != menu.answers.dayType }) { dayType in
                    Button(dayType.title) { withAnimation(.tap) { menu.setDayType(dayType) } }
                }
            } label: {
                Label("換日型", systemImage: "chevron.up.chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: Metrics.capsuleHeight)
                    .background(Theme.field, in: .capsule)
                    .contentShape(.capsule)
            }
            .accessibilityIdentifier("dayTypeMenu")
        }
    }
}

/// 一格一列：角色、選定的動作、小字的原因、處方（和安全提示）。點一下用系統的 Menu 列出前 5 個候選，
/// 第一個是建議，每個候選下面一行小字（建議的原因、或幾天前）；有氧固定是跑步機，不能換
private struct SlotRow: View {
    var state: PlanRanking.SlotState
    /// 選定動作的歷次紀錄（建議重量用）
    var logs: [ExerciseLog]
    var index: Int
    var onPick: (UUID) -> Void

    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg

    private var candidates: [PlanCandidate] { Array(state.candidates.items.prefix(PlanRanking.visibleCount)) }

    var body: some View {
        if state.slot != .cardio, candidates.count > 1 {
            Menu {
                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                    // 系統的選單項目：第一個 Text 是名稱、第二個是小字，Image 是目前選的勾勾
                    Button { onPick(candidate.id) } label: {
                        Text(candidate.exercise.name)
                        Text(PlanMenu.note(for: candidate, isSuggestion: index == 0, reason: state.candidates.reason))
                        if candidate.id == state.selected?.id { Image(systemName: "checkmark") }
                    }
                }
            } label: {
                label(showsChevron: true)
            }
            .menuStyle(.button)
            .buttonStyle(.tapRow)
            .tapRowOutset()
            .accessibilityIdentifier("planSlot-\(index)")
        } else {
            label(showsChevron: false)
                .tapRowOutset()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("planSlot-\(index)")
        }
    }

    private func label(showsChevron: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(state.slot.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                if let selected = state.selected {
                    Text(selected.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    reason(selected)
                    let advice = SlotAdvice.make(role: state.slot.role, exercise: selected, logs: logs, unit: unit)
                    Text(advice.line)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    if let tip = advice.prescription.tip {
                        Label(tip, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                    }
                } else {
                    Text("沒有符合的動作，這一格會略過")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .tapRowInset()
    }

    /// 選的是建議（第一個）：「建議」和原因（強調色）；換過的：幾天前（中性色）
    @ViewBuilder
    private func reason(_ selected: PlanExercise) -> some View {
        if let first = candidates.first, first.id == selected.id {
            HStack(spacing: 6) {
                AccentChip(text: "建議")
                if let reason = state.candidates.reason {
                    Text(reason).font(.footnote).foregroundStyle(Theme.accent)
                }
            }
        } else if let candidate = candidates.first(where: { $0.id == selected.id }) {
            Text(PlanMenu.note(for: candidate, isSuggestion: false, reason: nil))
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
