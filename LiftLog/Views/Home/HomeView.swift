import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ScreenHeader(title: "該練什麼")
                        GroupBarsCard(exercises: exercises) { group in
                            withAnimation { proxy.scrollTo(group, anchor: .top) }
                        }
                        ForEach(MuscleGroup.allCases) { group in
                            let items = exercises.filter { $0.primaryGroup == group }
                            if !items.isEmpty {
                                GroupSection(group: group, exercises: items)
                                    .id(group)
                            }
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
        // 開發用：啟動參數 -openExercise 槓鈴臥推 直接打開記錄頁
        // -openDetail 槓鈴臥推 直接打開動作詳情
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

/// 最近 30 天各部位訓練天數，點一下跳到該部位
private struct GroupBarsCard: View {
    var exercises: [Exercise]
    var onSelect: (MuscleGroup) -> Void

    private var counts: [MuscleGroup: Int] {
        let records = exercises.flatMap { ex in ex.entries.map { (date: $0.date, group: ex.primaryGroup) } }
        return Recency.trainingDaysByGroup(records)
    }

    var body: some View {
        let counts = counts
        let maxCount = max(counts.values.max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 12) {
            Text("最近 30 天")
                .font(.headline)
                .foregroundStyle(.secondary)
            ForEach(MuscleGroup.allCases) { group in
                let count = counts[group] ?? 0
                Button { onSelect(group) } label: {
                    HStack(spacing: 12) {
                        Text(group.title)
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

private struct GroupSection: View {
    var group: MuscleGroup
    var exercises: [Exercise]

    var body: some View {
        let sorted = Recency.sortedByNeglect(exercises, lastDate: { $0.lastEntry?.date }, name: \.name)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(group.title).font(.title2.bold())
                if let subtitle = group.subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)

            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, exercise in
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
                Text(exercise.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
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
