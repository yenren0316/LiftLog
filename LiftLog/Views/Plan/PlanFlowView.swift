import SwiftUI
import SwiftData

/// 打開建立菜單流程；answers 為 nil 時用預設答案
struct PlanRequest: Identifiable {
    let id = UUID()
    var answers: PlanAnswers?
}

/// 建立菜單：三個問題 → 每一格選一個動作（格子由日型和動作數決定）
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
    @State private var answers = PlanAnswers(dayType: .meLower, count: 3, cardio: false)
    @State private var showExercises = false
    /// 使用者在第二步點選的動作（格子 → 動作 id）
    @State private var picks: [Slot: UUID] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if history != nil {
                    QuestionsStep(answers: $answers) {
                        picks = [:]
                        showExercises = true
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("建立菜單")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .navigationDestination(isPresented: $showExercises) {
                if let history {
                    ExercisesStep(states: states(history), history: history,
                                  onPick: { slot, id in picks[slot] = id }, onStart: start)
                }
            }
            .screenBackground()
        }
        .task {
            guard history == nil else { return }
            let snapshot = PlanHistory(sessions: endedSessions)
            exercises = allExercises.map(PlanExercise.init)
            answers = initialAnswers ?? PlanDefaults.answers(snapshot)
            history = snapshot
            #if DEBUG
            // 開發用：-planStep 2 直接跳到選動作（截圖用）；-planAnswers deUpper,2,1 指定三個問題的答案
            let parts = UserDefaults.standard.string(forKey: "planAnswers")?.split(separator: ",") ?? []
            if parts.count == 3, let dayType = DayType(rawValue: String(parts[0])), let count = Int(parts[1]) {
                answers = PlanAnswers(dayType: dayType, count: count, cardio: parts[2] == "1")
            }
            if UserDefaults.standard.integer(forKey: "planStep") >= 2 { showExercises = true }
            #endif
        }
    }

    private func states(_ history: PlanHistory) -> [PlanRanking.SlotState] {
        PlanRanking.resolve(answers: answers, picks: picks, exercises: exercises, history: history)
    }

    private func start() {
        guard let history else { return }
        let byID = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        var chosen: [Exercise] = []
        var roles: [Role] = []
        for state in states(history) {
            guard let pick = state.selected, let exercise = byID[pick.id] else { continue }
            chosen.append(exercise)
            roles.append(state.slot.role)
        }
        guard !chosen.isEmpty else { return }
        WorkoutActions.start(with: chosen, roles: roles, dayType: answers.dayType, in: context)
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
                VStack(alignment: .leading, spacing: 14) {
                    Text("今天的日型").font(.title3.bold())
                    ForEach([[DayType.meLower, .meUpper], [.deLower, .deUpper]], id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(row) { dayType in
                                OptionButton(title: dayType.title, isSelected: answers.dayType == dayType) {
                                    answers.dayType = dayType
                                }
                            }
                        }
                    }
                }
                .card()
                question("今天做幾個動作？") {
                    ForEach(PlanAnswers.countOptions, id: \.self) { count in
                        OptionButton(title: "\(count) 個", isSelected: answers.count == count) {
                            answers.count = count
                        }
                    }
                }
                question("最後要加跑步機嗎？") {
                    OptionButton(title: "加", isSelected: answers.cardio) { answers.cardio = true }
                    OptionButton(title: "不加", isSelected: !answers.cardio) { answers.cardio = false }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("今天的順序").font(.headline).foregroundStyle(Theme.textSecondary)
                    FlowSlots(slots: Slot.slots(for: answers, mainCategory: nil))
                }
                .card()
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
        Button { withAnimation(.tap, action) } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(isSelected ? Theme.accent : Theme.field, in: .capsule)
        }
        .buttonStyle(.pressable)
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
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// 「ME 主項 → 下肢輔助 → 核心」，放不下時換行
private struct FlowSlots: View {
    var slots: [Slot]

    var body: some View {
        WrapLayout(spacing: 6) {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                HStack(spacing: 6) {
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
}

/// 由左到右排，超過寬度就換行
private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: frames.map(\.maxX).max() ?? 0, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, arrange(width: bounds.width, subviews: subviews)) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return frames
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

// MARK: - 第二步

private struct ExercisesStep: View {
    var states: [PlanRanking.SlotState]
    var history: PlanHistory
    var onPick: (Slot, UUID) -> Void
    var onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(states, id: \.slot) { state in
                    SlotCard(state: state, logs: state.selected.map { history.logs(for: $0.id) } ?? []) {
                        onPick(state.slot, $0)
                    }
                }
            }
            .padding(16)
            .animation(.tap, value: states.map(\.slot))
        }
        .navigationTitle("選動作")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "開始訓練", isEnabled: states.contains { $0.selected != nil }, action: onStart)
        }
    }
}

/// 一格：角色、預設參數、最多 5 個候選（第一個標「建議」和原因），選定動作的建議重量和提示
private struct SlotCard: View {
    var state: PlanRanking.SlotState
    /// 選定動作的歷次紀錄（建議重量用）
    var logs: [ExerciseLog]
    var onPick: (UUID) -> Void

    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @State private var showGuide = false

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
            if let selected = state.selected {
                advice(SlotAdvice.make(role: state.slot.role, exercise: selected, logs: logs, unit: unit))
                    .padding(.bottom, 8)
            }

            if items.isEmpty {
                Text("沒有符合的動作，這一格會略過")
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else if state.slot == .cardio {
                // 有氧固定是跑步機
                row(items[0], isFirst: false)
            } else {
                ForEach(Array(items.prefix(PlanRanking.visibleCount).enumerated()), id: \.element.id) { index, candidate in
                    if index > 0 { Divider().overlay(Theme.separator) }
                    row(candidate, isFirst: index == 0)
                }
            }
        }
        .card()
    }

    /// 「8 組 × 2 下・休息 45–60 秒」「建議 65 kg（…）」「設好安全槓」
    private func advice(_ advice: SlotAdvice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(advice.prescription.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            if let weight = advice.weightText {
                Text(weight).font(.subheadline.weight(.semibold))
            }
            if let tip = advice.prescription.tip {
                Label(tip, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.warning)
            }
        }
    }

    private func row(_ candidate: PlanCandidate, isFirst: Bool) -> some View {
        Button { withAnimation(.tap) { onPick(candidate.id) } } label: {
            CandidateRow(candidate: candidate, isSelected: state.selected?.id == candidate.id,
                         suggestion: isFirst ? .some(state.candidates.reason) : nil)
        }
        .buttonStyle(.pressable)
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
                    .contentTransition(.symbolEffect(.replace))
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
