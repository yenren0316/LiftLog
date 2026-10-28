import SwiftUI
import SwiftData

/// 第 1 層「動作庫」：只回答「我有哪些動作？」——9 個分類列和「已封存」。搜尋時直接列出所有分類的結果（不含封存）
struct LibraryView: View {
    enum Route: Hashable {
        case category(ExerciseCategory)
        case archived
    }

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(StatsCache.self) private var stats
    /// 導覽路徑放在環境裡：分類清單、已封存裡的列（LibraryExerciseRow）也要能推下一頁
    @State private var navigation = LibraryNavigation()
    @State private var query = ""
    @State private var showingNew = false

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.path) {
            List {
                if query.isEmpty {
                    if exercises.isEmpty {
                        Text("動作庫是空的。按右上角的＋新增動作，或到「設定 → 備份與還原」匯入備份。")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .listRowBackground(Theme.card)
                    }
                    Section {
                        ForEach(ExerciseCategory.allCases) { category in
                            TapListRow { navigation.path.append(Route.category(category)) } label: { categoryRow(category) }
                        }
                    }
                    Section {
                        TapListRow { navigation.path.append(Route.archived) } label: {
                            Text("已封存（\(exercises.filter(\.isArchived).count)）").font(.body.weight(.semibold))
                        }
                        .id("archived")
                    }
                } else {
                    let results = ExerciseLists.search(exercises, query: query)
                    if results.isEmpty {
                        Text("找不到「\(query)」").foregroundStyle(Theme.textSecondary).listRowBackground(Theme.card)
                    }
                    ForEach(results) { exercise in
                        LibraryExerciseRow(exercise: exercise, stat: stats.snapshot.exercises[exercise.id], showsCategory: true)
                    }
                }
            }
            .listSectionSpacing(12)
            .scrollContentBackground(.hidden)
            #if DEBUG
            .debugScrollToBottom("動作庫", "library", last: "archived")
            #endif
            .screenBackground()
            .navigationTitle("動作庫")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新增動作", systemImage: "plus") { showingNew = true }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋名稱、別名、英文名")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .category(let category): CategoryExerciseList(category: category)
                case .archived: ArchivedExerciseList()
                }
            }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            .libraryRowActionSheets()
            .sheet(isPresented: $showingNew) { ExerciseEditView(exercise: nil) }
            #if DEBUG
            // 開發用：-libraryCategory kneeDominant 直接打開該分類；-openArchived YES 打開已封存；
            // -openExercise 臥推 打開該動作的詳情（經過它的分類）
            .task {
                if let raw = UserDefaults.standard.string(forKey: "libraryCategory"), let category = ExerciseCategory(rawValue: raw) {
                    navigation.path.append(Route.category(category))
                }
                if let name = UserDefaults.standard.string(forKey: "openExercise"), let exercise = exercises.first(where: { $0.name == name }) {
                    navigation.path.append(Route.category(exercise.category))
                    navigation.path.append(exercise)
                }
                if UserDefaults.standard.bool(forKey: "openArchived") { navigation.path.append(Route.archived) }
            }
            #endif
        }
        .environment(navigation)
    }

    /// 分類名稱、「N 個動作・最久沒練：N 天」；有沒練過的動作時另外寫「M 個未練過」
    private func categoryRow(_ category: ExerciseCategory) -> some View {
        let members = exercises.filter { $0.category == category && !$0.isArchived }
        let dates = members.map { stats.snapshot.exercises[$0.id]?.lastDate }
        let untrained = dates.filter { $0 == nil }.count
        var parts = ["\(members.count) 個動作"]
        if let oldest = dates.compactMap({ $0 }).min() {
            parts.append("最久沒練：\(Recency.daysSince(oldest) ?? 0) 天")
        }
        if untrained > 0 { parts.append("\(untrained) 個未練過") }
        return VStack(alignment: .leading, spacing: 2) {
            Text(category.fullTitle).font(.body.weight(.semibold))
            Text(parts.joined(separator: "・")).font(.footnote).foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

/// 動作庫的導覽路徑（CHANGE_10 §4：清單的列改成整列可點的按鈕，不用 NavigationLink 的「›」）
@Observable
final class LibraryNavigation {
    var path = NavigationPath()
}

/// 第 2 層「分類清單」：右上角的排序和篩選（排序記住上次的選擇）
struct CategoryExerciseList: View {
    let category: ExerciseCategory

    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(StatsCache.self) private var stats
    @AppStorage(LibrarySort.storageKey) private var sort: LibrarySort = .stalest
    @State private var filter = LibraryFilter()
    @State private var showingOptions = false

    var body: some View {
        let members = exercises.filter { $0.category == category && filter.matches(tags: $0.tags) }
        let sorted = sort.sorted(members, lastDate: { stats.snapshot.exercises[$0.id]?.lastDate },
                                 count: { stats.snapshot.exercises[$0.id]?.sessionCount ?? 0 }, name: \.name)
        List {
            if sorted.isEmpty {
                Text(filter.tags.isEmpty ? "這個分類沒有動作" : "沒有符合篩選的動作")
                    .foregroundStyle(Theme.textSecondary)
                    .listRowBackground(Theme.card)
            }
            ForEach(sorted) { exercise in
                LibraryExerciseRow(exercise: exercise, stat: stats.snapshot.exercises[exercise.id])
            }
        }
        .scrollContentBackground(.hidden)
        #if DEBUG
        // 開發用：-libraryCategory core -scrollToBottom 分類 捲到分類清單的最底部（CHANGE_08 V1）
        .debugScrollToBottom("分類", "category", last: sorted.last?.id)
        #endif
        .screenBackground()
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingOptions = true } label: {
                    Image(systemName: filter.tags.isEmpty ? "line.3.horizontal.decrease.circle"
                                                          : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("排序與篩選")
                .popover(isPresented: $showingOptions) {
                    SortFilterPanel(sort: $sort, filter: $filter)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
        .libraryRowActionSheets()
        #if DEBUG
        // 開發用：-librarySortMenu YES 打開排序與篩選（截圖用）
        .task {
            if UserDefaults.standard.bool(forKey: "librarySortMenu") {
                try? await Task.sleep(for: .milliseconds(600))
                showingOptions = true
            }
        }
        #endif
    }
}

/// 排序（四選一）和篩選（主、單、爆，取交集）
private struct SortFilterPanel: View {
    @Binding var sort: LibrarySort
    @Binding var filter: LibraryFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("排序").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            ForEach(LibrarySort.allCases) { option in
                Button { withAnimation(.tap) { sort = option } } label: {
                    HStack {
                        Text(option.title)
                        Spacer()
                        if sort == option { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                    }
                    .tapRowInset()
                }
                .buttonStyle(.tapRow)
                .tapRowOutset()
            }
            Divider().overlay(Theme.separator)
            Text("篩選").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                ForEach(ExerciseTag.allCases) { tag in
                    FilterCapsule(title: tag.title, isSelected: filter.tags.contains(tag)) {
                        if filter.tags.contains(tag) { filter.tags.remove(tag) } else { filter.tags.insert(tag) }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 280)
        .foregroundStyle(Theme.textPrimary)
    }
}

/// 第 2 層「已封存」
struct ArchivedExerciseList: View {
    @Query(filter: #Predicate<Exercise> { $0.isArchived }, sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(StatsCache.self) private var stats

    var body: some View {
        List {
            if exercises.isEmpty {
                Text("沒有封存的動作").foregroundStyle(Theme.textSecondary).listRowBackground(Theme.card)
            }
            ForEach(exercises) { exercise in
                LibraryExerciseRow(exercise: exercise, stat: stats.snapshot.exercises[exercise.id], showsCategory: true)
            }
            Section {
            } footer: {
                Text("封存的動作不會出現在建議和新增動作裡，紀錄仍然保留。向左滑可以取消封存。")
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("已封存")
        .navigationBarTitleDisplayMode(.inline)
        .libraryRowActionSheets()
    }
}
