import SwiftUI
import SwiftData
import Charts

/// 歷程的「統計」（CHANGE_07 D-1）：主項進步、體重、有氧、訓練頻率、平衡。統計從 StatsCache 讀
struct HistoryStatsView: View {
    @Environment(StatsCache.self) private var stats

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MainLiftProgressCard(trends: stats.snapshot.mainLifts).id("mainLifts")
                    BodyWeightCard().id("weight")
                    CardioCard(minutes: stats.snapshot.weeklyCardioMinutes).id("cardio")
                    FrequencyCard(days: stats.snapshot.days, weekly: stats.snapshot.weeklySessions).id("frequency")
                    BalanceCard(balance: stats.snapshot.balance).id("balance")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .hidesTabBarOnScroll("history.stats")
            #if DEBUG
            .debugScrollToBottom("統計", "stats", last: "balance")
            // 開發用：-statsScrollTo cardio 捲到那張卡（截圖用）
            .task {
                if let id = UserDefaults.standard.string(forKey: "statsScrollTo") {
                    try? await Task.sleep(for: .milliseconds(400))
                    proxy.scrollTo(id, anchor: .top)
                }
            }
            #endif
        }
    }
}

/// 主項進步：90 天內有紀錄的「主」動作一列，估算 1RM、近 12 週的迷你折線、和 4 週前相比；點一列到動作詳情。
/// 90 天內沒練的主項只寫一行數量
private struct MainLiftProgressCard: View {
    var trends: [UUID: StatsSnapshot.MainLiftTrend]

    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name) private var exercises: [Exercise]
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg

    var body: some View {
        let order = ExerciseCategory.allCases
        let allMains = exercises.filter { $0.tags.contains(.main) }
        let mains = allMains.filter { trends[$0.id]?.current != nil }.sorted {
            (order.firstIndex(of: $0.category)!, $0.meRotation ?? .max) < (order.firstIndex(of: $1.category)!, $1.meRotation ?? .max)
        }
        let idle = allMains.count - mains.count
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("主項進步").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("估算 1RM・近 12 週").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 4)
            if allMains.isEmpty {
                Text("沒有標「主」的動作").font(.subheadline).foregroundStyle(Theme.textSecondary)
            } else if mains.isEmpty {
                Text("近 90 天沒有主項的紀錄").font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
            ForEach(Array(mains.enumerated()), id: \.element.id) { index, exercise in
                if index > 0 { Divider().overlay(Theme.separator) }
                NavigationLink(value: exercise) { row(exercise, trends[exercise.id]) }
                    .buttonStyle(.pressable)
            }
            if !mains.isEmpty, idle > 0 {
                Text("另外 \(idle) 個主項 90 天內沒有紀錄").font(.caption).foregroundStyle(Theme.textSecondary).padding(.top, 4)
            }
        }
        .card(padding: 16)
    }

    private func row(_ exercise: Exercise, _ trend: StatsSnapshot.MainLiftTrend?) -> some View {
        HStack(spacing: 10) {
            Text(exercise.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                .frame(width: 92, alignment: .leading)
            Sparkline(values: trend?.weekly ?? [])
                .frame(height: 24)
            VStack(alignment: .trailing, spacing: 0) {
                Text(trend?.current.map { unit.formatWithUnit(kg: $0) } ?? "—")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                if let change = trend?.change, unit.format(kg: abs(change)) != "0" {
                    Text("\(change > 0 ? "+" : "−")\(unit.format(kg: abs(change)))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(change > 0 ? Theme.done : Theme.danger)
                } else {
                    Text("和 4 週前一樣").font(.caption2).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 92, alignment: .trailing)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}

/// 近 12 週的迷你折線（沒練的週斷開）
private struct Sparkline: View {
    var values: [Double?]

    var body: some View {
        let points = values.enumerated().compactMap { index, value in value.map { (index, $0) } }
        if points.count >= 2 {
            Chart(points, id: \.0) { point in
                LineMark(x: .value("週", point.0), y: .value("1RM", point.1))
                    .foregroundStyle(Theme.accent)
                    .interpolationMethod(.monotone)
            }
            .chartXScale(domain: 0...max(values.count - 1, 1))
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        } else {
            Capsule().fill(Theme.field).frame(height: 2)
        }
    }
}

/// 有氧：近 12 週，每週跑步機的分鐘數
private struct CardioCard: View {
    var minutes: [Double]

    var body: some View {
        let weeks = Self.weekStarts(count: minutes.count)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("有氧").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("近 12 週・每週跑步機分鐘").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            if minutes.allSatisfy({ $0 == 0 }) {
                Text("近 12 週沒有跑步機紀錄").font(.subheadline).foregroundStyle(Theme.textSecondary)
            } else {
                Chart(Array(zip(weeks, minutes)), id: \.0) { week, value in
                    BarMark(x: .value("週", week, unit: .weekOfYear), y: .value("分鐘", value))
                        .foregroundStyle(Theme.accent)
                        .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    }
                }
                .frame(height: 120)
            }
        }
        .card(padding: 16)
    }

    private static func weekStarts(count: Int) -> [Date] {
        let calendar = Calendar.current
        return (0..<count).reversed().compactMap { back in
            calendar.date(byAdding: .weekOfYear, value: -back, to: .now)
                .flatMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start }
        }
    }
}

/// 訓練頻率：完整一年的訓練日曆，標題列「本週 N 次・近 12 週平均 M 次」；點有訓練的那天打開摘要浮窗
private struct FrequencyCard: View {
    var days: [Date: StatsSnapshot.DayStat]
    var weekly: [Int]

    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @State private var choices: [WorkoutSession] = []

    var body: some View {
        let average = weekly.isEmpty ? 0 : Double(weekly.reduce(0, +)) / Double(weekly.count)
        TrainingCalendar(days: days, mode: .year, title: "訓練頻率",
                         caption: "本週 \(weekly.last ?? 0) 次・近 12 週平均 \(average.formatted(.number.precision(.fractionLength(1)))) 次") { day in
            DaySessionChooser.open(day, context: context, coordinator: coordinator, choices: &choices)
        }
        .modifier(DaySessionChooser(choices: $choices))
    }
}

/// 平衡：近 30 天的推：拉組數比、單邊次數、爆發次數（拉比推少時推拉比用警示色）
private struct BalanceCard: View {
    var balance: StatsSnapshot.Balance

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("平衡・近 30 天").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 6) {
                Text("推：拉")
                Text("\(balance.push)：\(balance.pull)")
                    .font(.body.weight(.bold).monospacedDigit())
                    .foregroundStyle(balance.pull < balance.push ? Theme.warning : Theme.done)
                Text("・單邊 \(balance.unilateralSessions) 次・爆發 \(balance.explosiveSessions) 次")
                    .monospacedDigit()
            }
            .font(.body)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .card(padding: 16)
    }
}
