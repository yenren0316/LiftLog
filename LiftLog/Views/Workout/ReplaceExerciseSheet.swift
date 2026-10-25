import SwiftUI
import SwiftData

/// 換動作：候選規則和排序都和建立菜單第三步同一個位置相同，這次訓練已有的動作排除
struct ReplaceExerciseSheet: View {
    let item: SessionExercise
    var onPick: (Exercise, Role) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }) private var endedSessions: [WorkoutSession]
    @State private var ranked: RankedCandidates?

    private var slot: Slot { Slot(role: item.role, modeID: item.session?.modeID) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(item.role.shortGuide).foregroundStyle(.secondary)
                } header: {
                    Text("位置：\(slot.title)")
                }
                .listRowBackground(Theme.card)

                if let ranked {
                    Section {
                        if ranked.items.isEmpty {
                            Text("沒有符合的動作").foregroundStyle(.secondary)
                        }
                        ForEach(Array(ranked.items.enumerated()), id: \.element.id) { index, candidate in
                            Button { pick(candidate) } label: {
                                CandidateRow(candidate: candidate, isSelected: nil,
                                             suggestion: index == 0 ? .some(ranked.reason) : nil)
                            }
                            .buttonStyle(.plain)
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
        // 單邊依這次主項的分類排序
        let mainCategory = session?.orderedItems.first { $0 !== item && $0.role == .main }?.exercise?.category
        return PlanRanking.candidates(for: slot, exercises: exercises.map(PlanExercise.init),
                                      history: PlanHistory(sessions: endedSessions),
                                      excluding: inSession, mainCategory: mainCategory)
    }

    private func pick(_ candidate: PlanCandidate) {
        guard let exercise = exercises.first(where: { $0.id == candidate.id }) else { return }
        onPick(exercise, slot.role(for: candidate.exercise))
        dismiss()
    }
}
