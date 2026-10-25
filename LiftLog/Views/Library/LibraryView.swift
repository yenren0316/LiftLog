import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var showingNew = false
    @State private var filter = LibraryFilter()
    @State private var query = ""
    @State private var mergeSource: Exercise?
    @State private var deleteCandidate: Exercise?
    @AppStorage("library.showArchived") private var showArchived = false
    /// 收合的分類（rawValue 以逗號串起來保存）
    @AppStorage("library.collapsed") private var collapsedRaw = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterBar
                    Toggle("顯示已封存", isOn: $showArchived)
                        .font(.subheadline)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)

                let visible = ExerciseLists.library(exercises, showArchived: showArchived, filter: filter, query: query)
                ForEach(ExerciseCategory.allCases) { category in
                    let items = LibraryOrder.sorted(
                        visible.filter { $0.category == category },
                        tags: \.tags, equipment: \.equipment, count: \.trainingCount, name: \.name
                    )
                    if !items.isEmpty {
                        Section {
                            if !collapsed.contains(category) {
                                ForEach(items) { row($0) }
                            }
                        } header: {
                            sectionHeader(category, count: items.count)
                        }
                    }
                }

                Section {
                } footer: {
                    Text("長按動作可以合併或刪除。有紀錄的動作只能封存。")
                }
            }
            .listSectionSpacing(12)
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
                    if let exercise = deleteCandidate, exercise.sessionItems.isEmpty {
                        context.delete(exercise)
                        try? context.save()
                    }
                    deleteCandidate = nil
                }
            }
        }
    }

    // MARK: - 篩選

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.Trained.allCases) { option in
                    chip(option.title, selected: filter.trained == option) { filter.trained = option }
                }
            }
            HStack(spacing: 8) {
                ForEach(ExerciseTag.allCases) { tag in
                    chip(tag.title, selected: filter.tags.contains(tag), systemImage: filter.tags.contains(tag) ? "checkmark" : nil) {
                        if filter.tags.contains(tag) { filter.tags.remove(tag) } else { filter.tags.insert(tag) }
                    }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? .black : .primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(selected ? Theme.green : Theme.card, in: .capsule)
            .overlay(Capsule().stroke(Theme.cardBorder))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分區

    private var collapsed: Set<ExerciseCategory> {
        Set(collapsedRaw.split(separator: ",").compactMap { ExerciseCategory(rawValue: String($0)) })
    }

    private func toggleCollapsed(_ category: ExerciseCategory) {
        var set = collapsed
        if set.contains(category) { set.remove(category) } else { set.insert(category) }
        collapsedRaw = set.map(\.rawValue).sorted().joined(separator: ",")
    }

    private func sectionHeader(_ category: ExerciseCategory, count: Int) -> some View {
        Button { withAnimation { toggleCollapsed(category) } } label: {
            HStack {
                Text("\(category.fullTitle) · \(count)")
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(collapsed.contains(category) ? -90 : 0))
            }
            .font(.subheadline.weight(.semibold))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 列

    private func row(_ exercise: Exercise) -> some View {
        NavigationLink {
            ExerciseDetailView(exercise: exercise)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(exercise.name).font(.body.weight(.semibold))
                        ForEach(exercise.tags) { Chip(text: $0.title) }
                        if exercise.isArchived { Chip(text: "封存") }
                    }
                    Text(subtitle(for: exercise))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(exercise.trainingCount) 次")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .opacity(exercise.isArchived ? 0.6 : 1)
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
            if exercise.sessionItems.isEmpty {
                Button("刪除", systemImage: "trash", role: .destructive) { deleteCandidate = exercise }
            }
        }
    }

    /// 「器材 · 上次 2025/10/05」或「器材 · 未練過」；別名不顯示但可搜尋
    private func subtitle(for exercise: Exercise) -> String {
        let last = exercise.lastCompletedDate.map { "上次 \($0.shortDate)" } ?? "未練過"
        return "\(exercise.equipment.title) · \(last)"
    }
}
