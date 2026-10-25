import SwiftUI
import SwiftData

/// 新增或更換動作：依分類分組、組內最久沒做的在前，可搜尋（含別名）
struct ExercisePickerView: View {
    var title: String
    /// 只列出這個分類（換動作用）
    var category: ExerciseCategory?
    /// 不列出的動作（換動作時的原動作）
    var excluding: Exercise?
    /// 已在這次訓練裡的動作，顯示勾勾
    var alreadyAdded: Set<PersistentIdentifier> = []
    var onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var query = ""

    var body: some View {
        NavigationStack {
            let candidates = ExerciseLists.picker(exercises, category: category, excluding: excluding, query: query)
            // 未練過的放在各組最後
            let sections = Recency.sections(candidates, category: \.category, lastDate: \.lastCompletedDate,
                                            name: \.name, untrainedLast: true)
            List {
                if sections.isEmpty {
                    Text("沒有符合的動作").foregroundStyle(.secondary).listRowBackground(Theme.card)
                }
                ForEach(sections, id: \.category) { section in
                    Section(section.category.fullTitle) {
                        ForEach(section.items) { exercise in
                            Button {
                                onPick(exercise)
                                dismiss()
                            } label: {
                                row(exercise)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Theme.card)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋名稱、別名")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let days = Recency.daysSince(exercise.lastCompletedDate)
        return HStack(spacing: 8) {
            if alreadyAdded.contains(exercise.persistentModelID) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            }
            Text(exercise.name).font(.body.weight(.semibold))
            ForEach(exercise.tags) { Chip(text: $0.title) }
            Spacer()
            if let days {
                Text(days == 0 ? "今天" : "\(days) 天前")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Recency.staleness(days: days).color)
            } else {
                Chip(text: "未練過")
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
