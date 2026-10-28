import SwiftUI
import SwiftData
import Charts

/// 歷程的「統計」（CHANGE_07 D-1）：主項進步、體重、有氧、訓練頻率、平衡。統計從 StatsCache 讀
struct HistoryStatsView: View {
    @Environment(StatsCache.self) private var stats
    /// 每週目標：設定過就用設定的，沒設定過用近 12 週的平均（CHANGE_09 §1）
    @AppStorage(WeeklyGoal.goalKey) private var storedGoal = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MainLiftProgressCard(trends: stats.snapshot.mainLifts).id("mainLifts")
                    BodyWeightCard().id("weight")
                    CardioCard(minutes: stats.snapshot.weeklyCardioMinutes, now: stats.snapshot.now).id("cardio")
                    FrequencyCard(weeks: stats.snapshot.frequencyWeeks, months: stats.snapshot.frequencyMonths,
                                  goal: WeeklyGoal.goal(stored: storedGoal, automatic: stats.snapshot.automaticWeeklyGoal))
                        .id("frequency")
                    BalanceCard(balance: stats.snapshot.balance).id("balance")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
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
                    .buttonStyle(.tapRow)
                    .tapRowOutset()
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
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
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

/// 有氧：近 12 週，每週跑步機的分鐘數。點一下長條（或按住拖曳）浮出「10/19–10/25・120 分鐘」
private struct CardioCard: View {
    var minutes: [Double]
    /// 統計快照的「現在」：最後一根是這一週
    var now: Date

    @State private var selected: Date?

    var body: some View {
        let weeks = Self.weekStarts(count: minutes.count, now: now)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("有氧").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("近 12 週・每週跑步機分鐘").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            if minutes.allSatisfy({ $0 == 0 }) {
                Text("近 12 週沒有跑步機紀錄").font(.subheadline).foregroundStyle(Theme.textSecondary)
            } else {
                let current = selected.flatMap { date in weeks.indices.last { weeks[$0] <= date } }
                Chart {
                    ForEach(Array(zip(weeks, minutes)), id: \.0) { week, value in
                        BarMark(x: .value("週", week, unit: .weekOfYear, calendar: Self.calendar), y: .value("分鐘", value))
                            .foregroundStyle(Theme.accent)
                            .cornerRadius(3)
                    }
                    if let current {
                        RuleMark(x: .value("週", weeks[current], unit: .weekOfYear, calendar: Self.calendar))
                            .foregroundStyle(Theme.textSecondary.opacity(0.25))
                            .annotation(position: .overlay, alignment: .top, spacing: 0,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                                PeekLabel(text: label(week: weeks[current], minutes: minutes[current]))
                            }
                    }
                }
                // 上面留空間給標籤
                .chartYScale(domain: 0...((minutes.max() ?? 0) * 1.4))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 3, calendar: Self.calendar)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    }
                }
                .chartDateSelection($selected)
                .frame(height: 140)
                .accessibilityIdentifier("cardioChart")
                .accessibilityValue(current.map { label(week: weeks[$0], minutes: minutes[$0]) } ?? "")
            }
        }
        .card(padding: 16)
    }

    /// 週一開始的週（和訓練頻率、今天的日曆一致）
    private static let calendar = TrainingCount.weekCalendar()

    /// 「10/19–10/25・120 分鐘」
    private func label(week: Date, minutes: Double) -> String {
        let last = Self.calendar.date(byAdding: .day, value: 6, to: week) ?? week
        let format = Date.FormatStyle.dateTime.month(.defaultDigits).day()
        return "\(week.formatted(format))–\(last.formatted(format))・\(Units.number(minutes)) 分鐘"
    }

    private static func weekStarts(count: Int, now: Date) -> [Date] {
        (0..<count).reversed().compactMap { back in
            calendar.date(byAdding: .weekOfYear, value: -back, to: now)
                .flatMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start }
        }
    }
}

/// 訓練頻率（CHANGE_08 §3）：近 12 週或近 12 個月的訓練天數長條（TrainingCount 的規則：以天為單位，同一天的部位合併後疊色），
/// 虛線是平均（只算過完的週或月），「週」另外有一條實線是每週目標（CHANGE_09 §4）。
/// 點一下長條顯示那一段的次數和日期範圍（2 秒後消失），按住拖曳時跟著手指；不導向其他頁面
private struct FrequencyCard: View {
    var weeks: TrainingFrequency.Series
    var months: TrainingFrequency.Series
    var goal: Int

    @AppStorage("history.frequencyPeriod") private var period: TrainingFrequency.Period = .week
    @State private var selected: Date?

    var body: some View {
        let series = period == .week ? weeks : months
        let buckets = series.buckets
        let average = series.average
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("訓練頻率").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("本週 \(weeks.buckets.last?.total ?? 0)/\(goal)・近 12 週平均 \(Self.format(weeks.average)) 次")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Picker("期間", selection: $period.animation(.tap)) {
                ForEach(TrainingFrequency.Period.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if buckets.allSatisfy({ $0.total == 0 }) {
                Text(period == .week ? "近 12 週沒有訓練紀錄" : "近 12 個月沒有訓練紀錄")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                chart(buckets, average: average)
                // 放得下就一列，放不下時線的圖例換到第二列
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        RegionLegend(forBars: true)
                        Spacer(minLength: 0)
                        lineLegend(average: average)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        RegionLegend(forBars: true)
                        lineLegend(average: average)
                    }
                }
            }
        }
        .card(padding: 16)
        .onChange(of: period) { selected = nil }
        #if DEBUG
        // 開發用：-frequencyPeriod month 切到月；-frequencyPeek 3 顯示倒數第 4 段的標籤（截圖用）
        .task {
            if let raw = UserDefaults.standard.string(forKey: "frequencyPeriod"), let value = TrainingFrequency.Period(rawValue: raw) {
                period = value
            }
            if let back = UserDefaults.standard.string(forKey: "frequencyPeek"), let index = Int(back) {
                // 等切換期間清掉選取之後再選
                try? await Task.sleep(for: .milliseconds(300))
                let list = (period == .week ? weeks : months).buckets
                if list.indices.contains(list.count - 1 - index) { selected = list[list.count - 1 - index].start }
            }
        }
        #endif
    }

    private var unit: Calendar.Component { period == .week ? .weekOfYear : .month }
    /// 週一開始的週（和 StatsSnapshot 的分段一致）
    private let calendar = TrainingCount.weekCalendar()

    /// 「━ 目標 3　┄ 平均 3.8」（月只有平均）
    private func lineLegend(average: Double) -> some View {
        HStack(spacing: 12) {
            if period == .week {
                legendLine("目標 \(goal)", style: StrokeStyle(lineWidth: 1.5))
            }
            legendLine("平均 \(Self.format(average))", style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
        .font(.caption2)
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(1)
        .fixedSize()
    }

    private func legendLine(_ title: String, style: StrokeStyle) -> some View {
        HStack(spacing: 4) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 1))
                path.addLine(to: CGPoint(x: 14, y: 1))
            }
            .stroke(Theme.textSecondary, style: style)
            .frame(width: 14, height: 2)
            Text(title).monospacedDigit()
        }
    }

    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    private func chart(_ buckets: [TrainingFrequency.Bucket], average: Double) -> some View {
        // 目標線也要在圖裡
        let top = Double(max(buckets.map(\.total).max() ?? 0, period == .week ? goal : 0, 1))
        let current = selected.flatMap { date in buckets.first { $0.start <= date && date < $0.end } }
        return Chart {
            ForEach(buckets) { bucket in
                ForEach(DayRegion.stackOrder, id: \.self) { region in
                    if let count = bucket.counts[region], count > 0 {
                        BarMark(x: .value("期間", bucket.start, unit: unit, calendar: calendar), y: .value("次數", count))
                            .foregroundStyle(region.barFill)
                    }
                }
            }
            RuleMark(y: .value("平均", average))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Theme.textPrimary.opacity(0.7))
            // 每週目標：實線，只在「週」
            if period == .week {
                RuleMark(y: .value("目標", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .foregroundStyle(Theme.textPrimary)
            }
            if let current {
                RuleMark(x: .value("期間", current.start, unit: unit, calendar: calendar))
                    .foregroundStyle(Theme.textSecondary.opacity(0.25))
                    // 放在圖表裡最上面（長條上方留了空間），不蓋到上面的分段切換
                    .annotation(position: .overlay, alignment: .top, spacing: 0,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        PeekLabel(text: label(current))
                    }
            }
        }
        // 本週或本月還沒有紀錄時也留它的位置（沒有長條的段落不會自己出現在 x 軸上）
        .chartXScale(domain: (buckets.first?.start ?? .now)...(buckets.last?.end ?? .now))
        // 上面留空間給標籤
        .chartYScale(domain: 0...(top * 1.45))
        // 刻度只到最高的長條，上面留給標籤
        .chartYAxis {
            AxisMarks(values: Self.ticks(upTo: top)) { _ in
                AxisGridLine().foregroundStyle(Theme.separator)
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: unit, count: 3, calendar: calendar)) { _ in
                AxisValueLabel(format: period == .week ? .dateTime.month(.defaultDigits).day() : .dateTime.month(.defaultDigits))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        // 點一下顯示 2 秒；按住 0.2 秒後拖曳跟著手指，放開後 2 秒消失；上下滑交給捲動
        .chartDateSelection($selected)
        .frame(height: 150)
        // 選取的那一段也給 VoiceOver（UI 測試用它確認點一下有選到）
        .accessibilityIdentifier("frequencyChart")
        .accessibilityValue(current.map(label) ?? "")
    }

    /// 0 到最高值之間的整數刻度（2～4 個）
    static func ticks(upTo top: Double) -> [Double] {
        let step: Double = top <= 4 ? 1 : top <= 10 ? 2 : top <= 25 ? 5 : top <= 50 ? 10 : 20
        return Array(stride(from: 0, through: top, by: step))
    }

    /// 「10/13–10/19・3 次」或「2026 年 9 月・12 次」
    private func label(_ bucket: TrainingFrequency.Bucket) -> String {
        if period == .month {
            let parts = calendar.dateComponents([.year, .month], from: bucket.start)
            return "\(parts.year ?? 0) 年 \(parts.month ?? 0) 月・\(bucket.total) 次"
        }
        let last = calendar.date(byAdding: .day, value: -1, to: bucket.end) ?? bucket.end
        let format = Date.FormatStyle.dateTime.month(.defaultDigits).day()
        return "\(bucket.start.formatted(format))–\(last.formatted(format))・\(bucket.total) 次"
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
