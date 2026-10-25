import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exercise: Exercise

    @State private var showingEdit = false

    var body: some View {
        let items = exercise.completedItems
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InfoCard(exercise: exercise)
                TrendCard(exercise: exercise, items: items)
                HistoryCard(exercise: exercise, items: items)
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
    var items: [SessionExercise]

    private struct Point: Identifiable {
        var id: PersistentIdentifier
        var date: Date
        var value: Double
        var isMax: Bool
    }

    private var isCardio: Bool { exercise.logType == .cardio }

    /// 每次訓練一個點：當次最佳的正式組或 MAX 組（不含熱身）；跑步機取坡度
    private var points: [Point] {
        items.compactMap { item in
            guard let date = item.session?.startedAt else { return nil }
            let sets = item.completedSets.map(\.values)
            if isCardio {
                guard let incline = sets.compactMap(\.incline).max() else { return nil }
                return Point(id: item.persistentModelID, date: date, value: incline, isMax: false)
            }
            guard let best = SetLogic.best(sets, logType: exercise.logType) else { return nil }
            let isMax = sets.contains { $0.kind == .max && $0.weightKg == best }
            return Point(id: item.persistentModelID, date: date, value: best, isMax: isMax)
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
                Text("至少要兩次紀錄才能畫圖")
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
    var items: [SessionExercise]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全部紀錄（\(items.count) 次）").font(.headline).foregroundStyle(.secondary)
            if items.isEmpty {
                Text("還沒有紀錄").foregroundStyle(.secondary)
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().overlay(Theme.cardBorder) }
                if let session = item.session {
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        HistoryLine(item: item, date: session.startedAt).contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }
}

/// 一次訓練一行：日期 · 精簡的組數字；有備註時顯示在下面
private struct HistoryLine: View {
    var item: SessionExercise
    var date: Date

    var body: some View {
        let hasMax = item.completedSets.contains { $0.kind == .max }
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(date.shortDate)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: 12)
                Text(item.summary)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(hasMax ? Theme.orange : .primary)
                    .multilineTextAlignment(.trailing)
            }
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
