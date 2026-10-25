import SwiftUI
import SwiftData

/// 新增動作（例外用的自由選擇）：搜尋、分類與標籤兩排 chips 取交集、依分類分區可收合、可多選
struct AddExercisesSheet: View {
    /// 已在這次訓練裡的動作，顯示「已加入」且不能選
    var alreadyAdded: Set<UUID>
    var onAdd: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var query = ""
    @State private var category: ExerciseCategory?
    @State private var tag: ExerciseTag?
    @State private var collapsed: Set<ExerciseCategory> = []
    /// 依點選順序
    @State private var selected: [Exercise] = []

    var body: some View {
        NavigationStack {
            let visible = ExerciseLists.picker(exercises, category: category, excluding: nil, query: query)
                .filter { tag == nil || $0.tags.contains(tag!) }
            let sections = Recency.sections(visible, category: \.category, lastDate: \.lastCompletedDate, name: \.name)
            List {
                Section {
                    chipRow {
                        FilterChip(title: "全部分類", isSelected: category == nil) { category = nil }
                        ForEach(ExerciseCategory.allCases) { c in
                            FilterChip(title: c.title, isSelected: category == c) { category = category == c ? nil : c }
                        }
                    }
                    chipRow {
                        FilterChip(title: "全部標籤", isSelected: tag == nil) { tag = nil }
                        ForEach(ExerciseTag.allCases) { t in
                            FilterChip(title: t.title, isSelected: tag == t) { tag = tag == t ? nil : t }
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)

                if sections.isEmpty {
                    Text("沒有符合的動作").foregroundStyle(.secondary).listRowBackground(Theme.card)
                }
                ForEach(sections, id: \.category) { section in
                    Section {
                        if !collapsed.contains(section.category) {
                            ForEach(section.items) { row($0) }
                        }
                    } header: {
                        Button {
                            withAnimation {
                                if collapsed.contains(section.category) {
                                    collapsed.remove(section.category)
                                } else {
                                    collapsed.insert(section.category)
                                }
                            }
                        } label: {
                            HStack {
                                Text("\(section.category.fullTitle)（\(section.items.count)）")
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .rotationEffect(.degrees(collapsed.contains(section.category) ? -90 : 0))
                            }
                            .font(.headline)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋名稱、別名、英文名")
            .navigationTitle("新增動作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
    }

    private func chipRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { content() }
                .padding(.horizontal, 16)
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let added = alreadyAdded.contains(exercise.id)
        let isSelected = selected.contains { $0 === exercise }
        let days = Recency.daysSince(exercise.lastCompletedDate)
        return Button { toggle(exercise) } label: {
            HStack(spacing: 12) {
                Image(systemName: added || isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.green : .secondary)
                Text(exercise.name).font(.body.weight(.semibold))
                ForEach(exercise.tags) { Chip(text: $0.title) }
                Spacer()
                if added {
                    Chip(text: "已加入")
                } else if let days {
                    Text(days == 0 ? "今天" : "\(String(days)) 天前")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Recency.staleness(days: days).color)
                } else {
                    AccentChip(text: "新")
                }
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(added)
    }

    private func toggle(_ exercise: Exercise) {
        if let index = selected.firstIndex(where: { $0 === exercise }) {
            selected.remove(at: index)
        } else {
            selected.append(exercise)
        }
    }

    /// 已選的動作固定在底部，可以點 × 移除；最下方「加入（N）」
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if !selected.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selected) { exercise in
                            Button { toggle(exercise) } label: {
                                HStack(spacing: 6) {
                                    Text(exercise.name).font(.subheadline.weight(.semibold))
                                    Image(systemName: "xmark").font(.caption.bold())
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(Theme.field, in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            Button {
                onAdd(selected)
                dismiss()
            } label: {
                Text("加入（\(selected.count)）")
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.green.opacity(selected.isEmpty ? 0.4 : 1), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.background)
    }
}

/// 篩選用的膠囊（單選，可再點一次取消）
struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.black : Color.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(isSelected ? Theme.green : Theme.field, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}
