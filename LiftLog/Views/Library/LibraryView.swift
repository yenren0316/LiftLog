import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var showingNew = false
    @State private var showArchived = false
    @State private var filter: TagFilter = .all
    @State private var query = ""
    @State private var mergeSource: Exercise?
    @State private var deleteCandidate: Exercise?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TagFilterBar(selection: $filter)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)

                let visible = exercises.filter { $0.matches(filter, query: query) }
                ForEach(ExerciseCategory.allCases) { category in
                    let items = visible.filter { $0.category == category && !$0.isArchived }
                    if !items.isEmpty {
                        Section(category.fullTitle) {
                            ForEach(items) { row($0) }
                        }
                    }
                }

                let archived = visible.filter(\.isArchived)
                if !archived.isEmpty {
                    Section {
                        Toggle("顯示已封存（\(archived.count)）", isOn: $showArchived)
                            .listRowBackground(Theme.card)
                        if showArchived {
                            ForEach(archived) { row($0) }
                        }
                    }
                }

                Section {
                } footer: {
                    Text("長按動作可以合併或刪除。有紀錄的動作只能封存。")
                }
            }
            .listSectionSpacing(16)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("動作庫")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新增動作", systemImage: "plus") { showingNew = true }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋名稱、別名、英文名")
            .sheet(isPresented: $showingNew) {
                ExerciseEditView(exercise: nil)
            }
            .sheet(item: $mergeSource) { source in
                MergeTargetView(source: source)
            }
            .confirmationDialog(
                "刪除「\(deleteCandidate?.name ?? "")」？",
                isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }),
                titleVisibility: .visible
            ) {
                Button("刪除", role: .destructive) {
                    if let exercise = deleteCandidate, exercise.entries.isEmpty {
                        context.delete(exercise)
                        try? context.save()
                    }
                    deleteCandidate = nil
                }
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        NavigationLink {
            ExerciseDetailView(exercise: exercise)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(exercise.name).font(.body.weight(.semibold))
                        ForEach(exercise.tags) { Chip(text: $0.title) }
                    }
                    Text(subtitle(for: exercise))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(exercise.entries.count) 筆")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Theme.card)
        .swipeActions {
            Button(exercise.isArchived ? "取消封存" : "封存") {
                exercise.isArchived.toggle()
                try? context.save()
            }
            .tint(exercise.isArchived ? Theme.green : Theme.yellow)
        }
        .contextMenu {
            Button("合併到…", systemImage: "arrow.triangle.merge") { mergeSource = exercise }
            Button(exercise.isArchived ? "取消封存" : "封存", systemImage: "archivebox") {
                exercise.isArchived.toggle()
                try? context.save()
            }
            if exercise.entries.isEmpty {
                Button("刪除", systemImage: "trash", role: .destructive) { deleteCandidate = exercise }
            }
        }
    }

    private func subtitle(for exercise: Exercise) -> String {
        var parts = [exercise.equipment.title]
        if exercise.logType != .weight { parts.append(exercise.logType.title) }
        if !exercise.aliases.isEmpty { parts.append("別名：" + exercise.aliases.joined(separator: "、")) }
        return parts.joined(separator: " · ")
    }
}
