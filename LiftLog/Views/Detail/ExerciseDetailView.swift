import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exercise: Exercise

    @State private var showingEdit = false

    var body: some View {
        let entries = exercise.sortedEntries
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InfoCard(exercise: exercise)
                NavigationLink {
                    LogEntryView(exercise: exercise)
                } label: {
                    Label("記錄這個動作", systemImage: "plus")
                        .font(.title3.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Theme.green, in: .capsule)
                }
                .buttonStyle(.plain)
                TrendCard(exercise: exercise, entries: entries)
                HistoryCard(exercise: exercise, entries: entries)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編輯") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ExerciseEditView(exercise: exercise)
        }
    }
}

private struct InfoCard: View {
    var exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if exercise.isArchived {
                Label("已封存", systemImage: "archivebox")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.yellow)
            }
            row("分類", exercise.category.fullTitle)
            if !exercise.tags.isEmpty {
                row("標籤", exercise.tags.map(\.title).joined(separator: "、"))
            }
            if !exercise.englishName.isEmpty {
                row("英文名", exercise.englishName)
            }
            if !exercise.aliases.isEmpty {
                row("別名", exercise.aliases.joined(separator: "、"))
            }
            row("器材", exercise.equipment.title)
            row("紀錄類型", exercise.logType.title)
            if !exercise.note.isEmpty {
                Text(exercise.note).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value).font(.body.weight(.semibold)).multilineTextAlignment(.trailing)
        }
    }
}

private struct TrendCard: View {
    var exercise: Exercise
    var entries: [WorkoutEntry]

    private struct Point: Identifiable {
        var id: PersistentIdentifier
        var date: Date
        var value: Double
        var isMax: Bool
    }

    private var isCardio: Bool { exercise.logType == .cardio }

    private var points: [Point] {
        entries.compactMap { e in
            let value = isCardio ? e.incline : e.weightKg
            guard let value else { return nil }
            return Point(id: e.persistentModelID, date: e.date, value: value, isMax: e.isMax)
        }
    }

    var body: some View {
        let points = points
        let reversed = exercise.logType == .assisted
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isCardio ? "坡度趨勢" : reversed ? "輔助重量趨勢" : "重量趨勢")
                    .font(.headline).foregroundStyle(.secondary)
                Spacer()
                if reversed {
                    Text("越低越好 ↑").font(.caption).foregroundStyle(.secondary)
                }
            }
            if points.count < 2 {
                Text("至少要兩筆紀錄才能畫圖")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(points) { p in
                    LineMark(x: .value("日期", p.date), y: .value("重量", p.value))
                        .foregroundStyle(Theme.green.opacity(0.6))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("日期", p.date), y: .value("重量", p.value))
                        .foregroundStyle(by: .value("類型", p.isMax ? "MAX" : "一般"))
                        .symbol(by: .value("類型", p.isMax ? "MAX" : "一般"))
                        .symbolSize(p.isMax ? 90 : 40)
                }
                .chartForegroundStyleScale(["一般": Theme.green, "MAX": Theme.orange])
                .chartSymbolScale(["一般": .circle, "MAX": .diamond])
                .chartYScale(domain: .automatic(includesZero: false, reversed: reversed))
                .chartLegend(points.contains(where: \.isMax) ? .visible : .hidden)
                .frame(height: 220)
            }
        }
        .card()
    }
}

private struct HistoryCard: View {
    var exercise: Exercise
    var entries: [WorkoutEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全部紀錄（\(entries.count)）").font(.headline).foregroundStyle(.secondary)
            if entries.isEmpty {
                Text("還沒有紀錄").foregroundStyle(.secondary)
            }
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 { Divider().overlay(Theme.cardBorder) }
                NavigationLink {
                    LogEntryView(exercise: exercise, editing: entry)
                } label: {
                    EntryLine(entry: entry).contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }
}
