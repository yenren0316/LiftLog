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
                        FilterCapsule(title: "全部分類", isSelected: category == nil) { category = nil }
                        ForEach(ExerciseCategory.allCases) { c in
                            FilterCapsule(title: c.title, isSelected: category == c) { category = category == c ? nil : c }
                        }
                    }
                    chipRow {
                        FilterCapsule(title: "全部標籤", isSelected: tag == nil) { tag = nil }
                        ForEach(ExerciseTag.allCases) { t in
                            FilterCapsule(title: t.title, isSelected: tag == t) { tag = tag == t ? nil : t }
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)

                if sections.isEmpty {
                    Text("沒有符合的動作").foregroundStyle(Theme.textSecondary).listRowBackground(Theme.card)
                }
                ForEach(sections, id: \.category) { section in
                    Section {
                        if !collapsed.contains(section.category) {
                            ForEach(section.items) { row($0) }
                        }
                    } header: {
                        Button {
                            withAnimation(.tap) {
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
                        .buttonStyle(.pressable)
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
        return TapListRow { withAnimation(.tap) { toggle(exercise) } } label: {
            HStack(spacing: 12) {
                Image(systemName: added || isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
                Text(exercise.name).font(.body.weight(.semibold))
                ForEach(exercise.tags) { Chip(text: $0.title) }
                Spacer()
                if added {
                    Chip(text: "已加入")
                } else if let days {
                    Text(RelativeDay.text(days))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Recency.staleness(days: days).color)
                } else {
                    Chip(text: "新")
                }
            }
        }
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
                            Button { withAnimation(.tap) { toggle(exercise) } } label: {
                                HStack(spacing: 6) {
                                    Text(exercise.name).font(.subheadline.weight(.semibold))
                                    Image(systemName: "xmark").font(.caption.bold())
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: Metrics.capsuleHeight)
                                .background(Theme.field, in: .capsule)
                            }
                            .buttonStyle(.pressable)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            PrimaryButton(title: "加入（\(selected.count)）", isEnabled: !selected.isEmpty) {
                onAdd(selected)
                dismiss()
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.background)
    }
}
