import SwiftUI
import SwiftData

/// 換動作：候選規則和排序都和建立菜單同一格相同，這次訓練已有的動作排除
struct ReplaceExerciseSheet: View {
    let item: SessionExercise
    var onPick: (Exercise, Role) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }) private var endedSessions: [WorkoutSession]
    @State private var ranked: RankedCandidates?

    private var slot: Slot { Slot(role: item.role) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(item.role.shortGuide).foregroundStyle(Theme.textSecondary)
                } header: {
                    Text("格子：\(slot.title)")
                }
                .listRowBackground(Theme.card)

                if let ranked {
                    Section {
                        if ranked.items.isEmpty {
                            Text("沒有符合的動作").foregroundStyle(Theme.textSecondary)
                        }
                        ForEach(Array(ranked.items.enumerated()), id: \.element.id) { index, candidate in
                            TapListRow { pick(candidate) } label: {
                                CandidateRow(candidate: candidate, suggestion: index == 0 ? .some(ranked.reason) : nil)
                            }
                        }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("換動作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
        .task { ranked = rank() }
    }

    private func rank() -> RankedCandidates {
        let session = item.session
        let inSession = Set(session?.items.compactMap { $0.exercise?.id } ?? [])
        // 下肢輔助依這次主項的分類排序
        let main = session?.orderedItems.first { $0 !== item && ($0.role == .maxEffort || $0.role == .dynamicEffort) }?
            .exercise.map { PlanExercise($0) }
        return PlanRanking.candidates(for: slot, dayType: session?.dayType, exercises: exercises.map { PlanExercise($0) },
                                      history: PlanHistory(sessions: endedSessions), excluding: inSession, main: main)
    }

    private func pick(_ candidate: PlanCandidate) {
        guard let exercise = exercises.first(where: { $0.id == candidate.id }) else { return }
        onPick(exercise, slot.role)
        dismiss()
    }
}

/// 候選動作的一列：名稱、標籤、「新」、建議與原因、幾天沒做
struct CandidateRow: View {
    var candidate: PlanCandidate
    /// 有值代表是建議的那一個；內層是原因
    var suggestion: String??

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(candidate.exercise.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    ForEach(candidate.exercise.tags) { Chip(text: $0.title) }
                    if candidate.isNew { Chip(text: "新") }
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
                Recency.staleness(days: days).text(RelativeDay.text(days))
                    .font(.headline.monospacedDigit())
            }
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}
