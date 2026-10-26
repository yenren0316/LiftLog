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
                    FrequencyCard(weeks: stats.snapshot.frequencyWeeks, months: stats.snapshot.frequencyMonths).id("frequency")
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

/// 訓練頻率（CHANGE_08 §3）：近 12 週或近 12 個月的訓練次數長條，依部位分段疊色，虛線是平均。
/// 點一下長條顯示那一段的次數和日期範圍（2 秒後消失），按住拖曳時跟著手指；不導向其他頁面
private struct FrequencyCard: View {
    var weeks: [TrainingFrequency.Bucket]
    var months: [TrainingFrequency.Bucket]

    @AppStorage("history.frequencyPeriod") private var period: TrainingFrequency.Period = .week
    @State private var selected: Date?
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        let buckets = period == .week ? weeks : months
        let average = TrainingFrequency.average(buckets)
        let weekAverage = TrainingFrequency.average(weeks)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("訓練頻率").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("本週 \(weeks.last?.total ?? 0) 次・近 12 週平均 \(weekAverage.formatted(.number.precision(.fractionLength(1)))) 次")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
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
                HStack(spacing: 12) {
                    RegionLegend(forBars: true)
                    Spacer(minLength: 0)
                    // 虛線＝平均
                    HStack(spacing: 4) {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0.5))
                            path.addLine(to: CGPoint(x: 14, y: 0.5))
                        }
                        .stroke(Theme.textSecondary, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .frame(width: 14, height: 1)
                        Text("平均 \(average.formatted(.number.precision(.fractionLength(1))))").monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
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
                let list = period == .week ? weeks : months
                if list.indices.contains(list.count - 1 - index) { selected = list[list.count - 1 - index].start }
            }
        }
        #endif
    }

    private var unit: Calendar.Component { period == .week ? .weekOfYear : .month }

    private func chart(_ buckets: [TrainingFrequency.Bucket], average: Double) -> some View {
        let top = Double(max(buckets.map(\.total).max() ?? 0, 1))
        let current = selected.flatMap { date in buckets.first { $0.start <= date && date < $0.end } }
        return Chart {
            ForEach(buckets) { bucket in
                ForEach(DayRegion.stackOrder, id: \.self) { region in
                    if let count = bucket.counts[region], count > 0 {
                        BarMark(x: .value("期間", bucket.start, unit: unit), y: .value("次數", count))
                            .foregroundStyle(region.barFill)
                    }
                }
            }
            RuleMark(y: .value("平均", average))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Theme.textPrimary.opacity(0.7))
            if let current {
                RuleMark(x: .value("期間", current.start, unit: unit))
                    .foregroundStyle(Theme.textSecondary.opacity(0.25))
                    // 放在圖表裡最上面（長條上方留了空間），不蓋到上面的分段切換
                    .annotation(position: .overlay, alignment: .top, spacing: 0,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        PeekLabel(text: label(current))
                    }
            }
        }
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
            AxisMarks(values: .stride(by: unit, count: 3)) { _ in
                AxisValueLabel(format: period == .week ? .dateTime.month(.defaultDigits).day() : .dateTime.month(.defaultDigits))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(.rect)
                    // 點一下：顯示 2 秒
                    .gesture(SpatialTapGesture().onEnded { value in
                        select(at: value.location, proxy: proxy, geometry: geometry)
                        hide(after: .seconds(2))
                    })
                    // 按住拖曳：跟著手指，放開就消失（短按住才開始，捲動頁面不受影響）
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.2)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            if case .second(true, let drag?) = value {
                                hideTask?.cancel()
                                select(at: drag.location, proxy: proxy, geometry: geometry)
                            }
                        }
                        .onEnded { _ in hide(after: .zero) })
            }
        }
        .frame(height: 150)
    }

    /// 0 到最高值之間的整數刻度（2～4 個）
    static func ticks(upTo top: Double) -> [Double] {
        let step: Double = top <= 4 ? 1 : top <= 10 ? 2 : top <= 25 ? 5 : top <= 50 ? 10 : 20
        return Array(stride(from: 0, through: top, by: step))
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plot = proxy.plotFrame else { return }
        let x = location.x - geometry[plot].origin.x
        selected = proxy.value(atX: x, as: Date.self)
    }

    private func hide(after delay: Duration) {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            selected = nil
        }
    }

    /// 「10/13–10/19・3 次」或「2026 年 9 月・12 次」
    private func label(_ bucket: TrainingFrequency.Bucket) -> String {
        let calendar = Calendar.current
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
