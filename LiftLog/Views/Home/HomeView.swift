import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name)
    private var exercises: [Exercise]
    @Query private var allEntries: [WorkoutEntry]

    @State private var path = NavigationPath()
    @State private var filter: TagFilter = .all

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ScreenHeader(title: "該練什麼")
                        ActivityGraph(entryDates: allEntries.map(\.date))
                        CategoryBarsCard(exercises: exercises) { category in
                            withAnimation { proxy.scrollTo(category, anchor: .top) }
                        }
                        TagFilterBar(selection: $filter)

                        let visible = exercises.filter { $0.matches(filter) }
                        let sections = Recency.sections(
                            visible, category: \.category, lastDate: { $0.lastEntry?.date }, name: \.name
                        )
                        if sections.isEmpty {
                            Text("沒有符合的動作").foregroundStyle(.secondary).card()
                        }
                        ForEach(sections, id: \.category) { section in
                            CategorySection(category: section.category, exercises: section.items)
                                .id(section.category)
                        }
                        StalenessLegend()
                    }
                    .padding(16)
                }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Exercise.self) { exercise in
                LogEntryView(exercise: exercise)
            }
            #if DEBUG
            .navigationDestination(for: DebugDetailRoute.self) { ExerciseDetailView(exercise: $0.exercise) }
            #endif
        }
        #if DEBUG
        // 開發用：啟動參數 -openExercise 臥推 直接打開記錄頁；-openDetail 臥推 直接打開動作詳情
        .task {
            let defaults = UserDefaults.standard
            if let name = defaults.string(forKey: "openExercise"),
               let exercise = exercises.first(where: { $0.name == name }) {
                path.append(exercise)
            }
            if let name = defaults.string(forKey: "openDetail"),
               let exercise = exercises.first(where: { $0.name == name }) {
                path.append(DebugDetailRoute(exercise: exercise))
            }
        }
        #endif
    }
}

/// 最近 30 天各分類訓練天數，點一下跳到該分類；下方是單邊、爆發的天數
private struct CategoryBarsCard: View {
    var exercises: [Exercise]
    var onSelect: (ExerciseCategory) -> Void

    var body: some View {
        let entries = exercises.flatMap { ex in ex.entries.map { (entry: $0, exercise: ex) } }
        let counts = Recency.trainingDays(entries.map { (date: $0.entry.date, key: $0.exercise.category) })
        let tagCounts = Recency.trainingDays(entries.flatMap { pair in
            pair.exercise.tags.map { (date: pair.entry.date, key: $0) }
        })
        // 沒有動作的分類（例如違常姿勢）不顯示
        let categories = ExerciseCategory.allCases.filter { c in exercises.contains { $0.category == c } }
        let maxCount = max(counts.values.max() ?? 0, 1)

        VStack(alignment: .leading, spacing: 12) {
            Text("最近 30 天")
                .font(.headline)
                .foregroundStyle(.secondary)
            ForEach(categories) { category in
                let count = counts[category] ?? 0
                Button { onSelect(category) } label: {
                    HStack(spacing: 12) {
                        Text(category.title)
                            .font(.body.weight(.semibold))
                            .frame(width: 96, alignment: .leading)
                        ThinBar(fraction: Double(count) / Double(maxCount), color: color(for: count))
                        Text("\(count) 天")
                            .font(.body.weight(.bold).monospacedDigit())
                            .foregroundStyle(color(for: count))
                            .frame(width: 52, alignment: .trailing)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            Divider().overlay(Theme.cardBorder)
            HStack(spacing: 24) {
                ForEach(ExerciseTag.allCases) { tag in
                    let count = tagCounts[tag] ?? 0
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(tag.title).font(.body.weight(.semibold))
                        Text(String(count))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(color(for: count))
                        Text("天").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .card()
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: Theme.red
        case 1...2: Theme.yellow
        default: Theme.green
        }
    }
}

private struct CategorySection: View {
    var category: ExerciseCategory
    var exercises: [Exercise]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(category.title).font(.title2.bold())
                if let subtitle = category.subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)

            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                if index > 0 { Divider().overlay(Theme.cardBorder) }
                NavigationLink(value: exercise) {
                    ExerciseRow(exercise: exercise)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }
}

struct ExerciseRow: View {
    var exercise: Exercise

    var body: some View {
        let last = exercise.lastEntry
        let days = Recency.daysSince(last?.date)
        let staleness = Recency.staleness(days: days)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    ForEach(exercise.tags) { Chip(text: $0.title) }
                }
                if let last {
                    Text("\(last.date.shortDate) · \(last.summary)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                if let days {
                    Text(days == 0 ? "今天" : String(days))
                        .font(.title2.weight(.bold).monospacedDigit())
                    if days > 0 {
                        Text("天前").font(.caption)
                    }
                } else {
                    Text("沒做過").font(.headline)
                }
            }
            .foregroundStyle(staleness.color)
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}

private struct StalenessLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            item(Theme.green, "60 天內")
            item(Theme.yellow, "超過 60 天")
            item(Theme.red, "超過 180 天")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .card(padding: 14)
    }

    private func item(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

#if DEBUG
private struct DebugDetailRoute: Hashable {
    var exercise: Exercise
}
#endif
