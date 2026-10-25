import SwiftUI
import SwiftData

/// 合併動作：選目標 → 確認 → 紀錄移到目標、名稱與別名併入目標、刪除來源
struct MergeTargetView: View {
    let source: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var query = ""
    @State private var target: Exercise?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("「\(source.name)」的 \(source.completedItems.count) 次紀錄會移到你選的動作，名稱和別名會變成目標的別名，然後刪除「\(source.name)」。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .listRowBackground(Color.clear)
                }
                let candidates = exercises.filter {
                    $0 !== source
                        && ExerciseSearch.matches(query: query, name: $0.name, aliases: $0.aliases, englishName: $0.englishName)
                }
                ForEach(ExerciseCategory.allCases) { category in
                    let items = candidates.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category.fullTitle) {
                            ForEach(items) { exercise in
                                Button { target = exercise } label: {
                                    HStack {
                                        Text(exercise.name).foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                        Text("\(exercise.completedItems.count) 次").foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                .listRowBackground(Theme.card)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .searchable(text: $query, prompt: "搜尋目標動作")
            .navigationTitle("合併「\(source.name)」到…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .confirmationDialog(
                "合併到「\(target?.name ?? "")」？",
                isPresented: Binding(get: { target != nil }, set: { if !$0 { target = nil } }),
                titleVisibility: .visible
            ) {
                Button("合併", role: .destructive, action: merge)
            } message: {
                Text("這個動作無法復原。")
            }
            .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") {}
            }
        }
    }

    private func merge() {
        guard let target else { return }
        do {
            try ExerciseMerge.merge(source, into: target, context: context)
            dismiss()
        } catch {
            errorMessage = "合併失敗：\(error.localizedDescription)"
        }
    }
}
