import SwiftUI
import SwiftData

/// 打開建立菜單流程；answers 為 nil 時用預設答案
struct PlanRequest: Identifiable {
    let id = UUID()
    var answers: PlanAnswers?
}

private enum PlanStep: Hashable {
    case mode, exercises
}

/// 建立菜單：三個問題 → 組合模式 → 每個位置選一個動作
struct PlanFlowView: View {
    var initialAnswers: PlanAnswers?
    /// 已建立訓練；呼叫端在 sheet 關閉後展開訓練中畫面
    var onStarted: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }) private var endedSessions: [WorkoutSession]

    /// 打開時建立一次快照，流程中不會變
    @State private var history: PlanHistory?
    @State private var exercises: [PlanExercise] = []
    @State private var answers = PlanAnswers(region: .lower, count: 3, cardio: false)
    @State private var path: [PlanStep] = []
    @State private var modeID: String?
    /// 使用者在第三步點選的動作（位置 index → 動作 id）
    @State private var picks: [Int: UUID] = [:]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if history != nil {
                    QuestionsStep(answers: $answers, onNext: next)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("建立菜單")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .navigationDestination(for: PlanStep.self) { step in
                if let history {
                    switch step {
                    case .mode:
                        ModeStep(modes: modes, recommended: PlanModes.recommended(modes, history: history),
                                 selection: $modeID) { path.append(.exercises) }
                    case .exercises:
                        ExercisesStep(states: states(history), onPick: { index, id in picks[index] = id },
                                      onStart: start)
                    }
                }
            }
            .screenBackground()
        }
        .onChange(of: modeID) { picks = [:] }
        .task {
            guard history == nil else { return }
            let snapshot = PlanHistory(sessions: endedSessions)
            exercises = allExercises.map(PlanExercise.init)
            answers = initialAnswers ?? PlanDefaults.answers(snapshot)
            history = snapshot
            #if DEBUG
            // 開發用：-planStep 2 或 3 直接跳到該步驟（截圖用）
            // -planAnswers lower,3,1 指定三個問題的答案
            let parts = UserDefaults.standard.string(forKey: "planAnswers")?.split(separator: ",") ?? []
            if parts.count == 3, let region = Region(rawValue: String(parts[0])), let count = Int(parts[1]) {
                answers = PlanAnswers(region: region, count: count, cardio: parts[2] == "1")
            }
            let step = UserDefaults.standard.integer(forKey: "planStep")
            if step >= 2 { next() }
            if step >= 3, path.last == .mode { path.append(.exercises) }
            #endif
        }
    }

    private var modes: [PlanMode] {
        PlanModes.modes(region: answers.region, count: answers.count)
    }

    private var slots: [Slot] {
        let mode = modes.first { $0.id == modeID } ?? modes.first
        return (mode?.slots ?? []) + (answers.cardio ? [.cardio] : [])
    }

    private func states(_ history: PlanHistory) -> [PlanRanking.SlotState] {
        PlanRanking.resolve(slots: slots, picks: picks, exercises: exercises, history: history)
    }

    /// 只有一個模式時直接進入第三步
    private func next() {
        guard let history else { return }
        picks = [:]
        if modes.count == 1 {
            modeID = modes.first?.id
            path.append(.exercises)
        } else {
            modeID = PlanModes.recommended(modes, history: history)?.id
            path.append(.mode)
        }
    }

    private func start() {
        guard let history else { return }
        let byID = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        var chosen: [Exercise] = []
        var roles: [Role] = []
        for state in states(history) {
            guard let pick = state.selected, let exercise = byID[pick.id] else { continue }
            chosen.append(exercise)
            roles.append(state.slot.role(for: pick))
        }
        guard !chosen.isEmpty else { return }
        WorkoutActions.start(with: chosen, roles: roles, region: answers.region, modeID: modeID, in: context)
        onStarted()
        dismiss()
    }
}

// MARK: - 第一步

private struct QuestionsStep: View {
    @Binding var answers: PlanAnswers
    var onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                question("今天練哪裡？") {
                    ForEach([Region.upper, .lower, .full]) { region in
                        OptionButton(title: region.title, isSelected: answers.region == region) {
                            answers.setRegion(region)
                        }
                    }
                }
                question("今天做幾個動作？") {
                    ForEach(PlanAnswers.countOptions(for: answers.region), id: \.self) { count in
                        OptionButton(title: "\(count) 個", isSelected: answers.count == count) {
                            answers.count = count
                        }
                    }
                }
                question("最後要加跑步機嗎？") {
                    OptionButton(title: "加", isSelected: answers.cardio) { answers.cardio = true }
                    OptionButton(title: "不加", isSelected: !answers.cardio) { answers.cardio = false }
                }
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "下一步", action: onNext)
        }
    }

    private func question<Options: View>(_ title: String, @ViewBuilder options: () -> Options) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.bold())
            HStack(spacing: 10) { options() }
        }
        .card()
    }
}

private struct OptionButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(isSelected ? Theme.accent : Theme.field, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryButton: View {
    var title: String
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(Theme.accent.opacity(isEnabled ? 1 : 0.4), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - 第二步

private struct ModeStep: View {
    var modes: [PlanMode]
    var recommended: PlanMode?
    @Binding var selection: String?
    var onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(modes) { mode in
                    Button { selection = mode.id } label: { card(mode) }
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .navigationTitle("選擇組合")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "下一步", isEnabled: selection != nil, action: onNext)
        }
    }

    private func card(_ mode: PlanMode) -> some View {
        let selected = selection == mode.id
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                Text("模式 \(mode.variant ?? "")").font(.title2.bold())
                if mode.id == recommended?.id { AccentChip(text: "建議") }
                Spacer()
            }
            FlowSlots(slots: mode.slots)
        }
        .card()
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(selected ? Theme.accent : .clear, lineWidth: 2))
        .contentShape(.rect)
    }
}

/// 「爆發 → 主項 → 單邊」
private struct FlowSlots: View {
    var slots: [Slot]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                if index > 0 {
                    Image(systemName: "arrow.right").font(.caption.bold()).foregroundStyle(Theme.textSecondary)
                }
                Text(slot.title)
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(Theme.field, in: .capsule)
            }
        }
    }
}

/// 強調色的小膠囊（建議、新）
struct AccentChip: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Theme.accent, in: .capsule)
    }
}

// MARK: - 第三步

private struct ExercisesStep: View {
    var states: [PlanRanking.SlotState]
    var onPick: (Int, UUID) -> Void
    var onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(states.enumerated()), id: \.offset) { index, state in
                    SlotCard(state: state) { onPick(index, $0) }
                }
            }
            .padding(16)
        }
        .navigationTitle("選動作")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "開始訓練", isEnabled: states.contains { $0.selected != nil }, action: onStart)
        }
    }
}

private struct SlotCard: View {
    var state: PlanRanking.SlotState
    var onPick: (UUID) -> Void

    @State private var showAll = false
    @State private var showGuide = false
    private static let visibleCount = 5

    var body: some View {
        let items = state.candidates.items
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.slot.title).font(.title2.bold())
                Spacer()
                Button { showGuide = true } label: {
                    Image(systemName: "info.circle").font(.title3)
                }
                .popover(isPresented: $showGuide) {
                    Text(state.slot.role.guide)
                        .font(.body)
                        .padding(20)
                        .frame(idealWidth: 320)
                        .presentationCompactAdaptation(.popover)
                }
            }
            Text(state.slot.role.shortGuide)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 8)

            if items.isEmpty {
                Text("沒有符合的動作，這個位置會略過")
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else if state.slot == .cardio {
                // 有氧固定是跑步機
                row(items[0], isFirst: false)
            } else {
                let shown = showAll ? items : Array(items.prefix(Self.visibleCount))
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, candidate in
                    if index > 0 { Divider().overlay(Theme.separator) }
                    row(candidate, isFirst: index == 0)
                }
                if items.count > Self.visibleCount {
                    Button { withAnimation { showAll.toggle() } } label: {
                        Text(showAll ? "收起" : "顯示全部（\(items.count)）")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .card()
    }

    private func row(_ candidate: PlanCandidate, isFirst: Bool) -> some View {
        Button { onPick(candidate.id) } label: {
            CandidateRow(candidate: candidate, isSelected: state.selected?.id == candidate.id,
                         suggestion: isFirst ? .some(state.candidates.reason) : nil)
        }
        .buttonStyle(.plain)
    }
}

/// 候選動作的一列：單選圈、名稱、標籤、「新」、建議與原因、幾天沒做（建立菜單與換動作共用）
struct CandidateRow: View {
    var candidate: PlanCandidate
    var isSelected: Bool?
    /// 有值代表是建議的那一個；內層是原因
    var suggestion: String??

    var body: some View {
        HStack(spacing: 12) {
            if let isSelected {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(candidate.exercise.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    ForEach(candidate.exercise.tags) { Chip(text: $0.title) }
                    if candidate.isNew { AccentChip(text: "新") }
                }
                if let suggestion {
                    HStack(spacing: 6) {
                        AccentChip(text: "建議")
                        if let reason = suggestion {
                            Text(reason).font(.subheadline).foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            if let days = candidate.daysSince {
                Text(days == 0 ? "今天" : "\(String(days)) 天")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Recency.staleness(days: days).color)
            }
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}
