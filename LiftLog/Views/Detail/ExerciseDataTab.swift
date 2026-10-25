import SwiftUI
import SwiftData
import Charts

/// 數據分頁：個人紀錄、折線圖、強度換算表、同分類替代動作
struct ExerciseDataTab: View {
    let exercise: Exercise
    var onOpenSession: (UUID) -> Void

    var body: some View {
        let sessions = exercise.sessionSets
        VStack(alignment: .leading, spacing: 20) {
            RecordsCard(exercise: exercise, sessions: sessions, onOpenSession: onOpenSession)
            TrendChartCard(exercise: exercise, sessions: sessions, onOpenSession: onOpenSession)
            if exercise.logType == .weight {
                IntensityCard(exercise: exercise, sessions: sessions)
            }
            AlternativesCard(exercise: exercise)
        }
    }
}

// MARK: - (a) 個人紀錄

private struct RecordsCard: View {
    let exercise: Exercise
    let sessions: [SessionSets]
    var onOpenSession: (UUID) -> Void
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg

    var body: some View {
        let records = PersonalRecords.records(sessions, logType: exercise.logType)
        VStack(alignment: .leading, spacing: 12) {
            Label("個人紀錄", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(Theme.yellow)
            if records.isEmpty {
                Text(exercise.logType == .cardio ? "有氧沒有個人紀錄，請看下方圖表。" : "還沒有紀錄")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                if index > 0 { Divider().overlay(Theme.cardBorder) }
                Button { onOpenSession(record.sessionID) } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.title).font(.body.weight(.semibold))
                            Text(record.date.shortDate + (record.caption.map { " · \($0)" } ?? ""))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(valueText(record))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(Theme.green)
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private func valueText(_ r: PersonalRecords.Record) -> String {
        switch r.kind {
        case .weight:
            let w = unit.formatWithUnit(kg: r.value)
            return r.reps.map { "\(w) × \($0)" } ?? w
        case .reps: return "\(Int(r.value)) 下"
        case .seconds: return "\(Units.number(r.value)) 秒"
        }
    }
}

// MARK: - (b) 折線圖

private struct TrendChartCard: View {
    let exercise: Exercise
    let sessions: [SessionSets]
    var onOpenSession: (UUID) -> Void

    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @State private var range: ChartRange = .oneYear
    @State private var chosenMetric: ChartMetric?
    @State private var selected: ChartPoints.Point?

    private var metric: ChartMetric {
        chosenMetric ?? ChartMetric.defaultMetric(for: exercise.logType, sessions: sessions)
    }

    var body: some View {
        let metric = metric
        let logType = exercise.logType
        let points = ChartPoints.filter(ChartPoints.points(sessions, logType: logType, metric: metric), range: range)
        let reversed = ChartPoints.isReversed(logType) && metric == .heaviest

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("趨勢").font(.headline).foregroundStyle(.secondary)
                if reversed {
                    Text("越低越好 ↑").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if metric.isWeight || logType == .assisted {
                    Picker("單位", selection: $unit) {
                        ForEach(WeightUnit.allCases) { Text($0.symbol).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }
            }

            let options = ChartMetric.options(for: logType)
            if !options.isEmpty {
                Picker("指標", selection: Binding(get: { metric }, set: { chosenMetric = $0 })) {
                    ForEach(options) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Picker("範圍", selection: $range) {
                ForEach(ChartRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if points.count < 2 {
                Text("紀錄不足，無法畫圖")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Text(selected.map { "\($0.date.shortDate) · \(valueText($0.value, metric: metric))" }
                     ?? "長按拖曳看數值，點一下打開那次訓練")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(selected == nil ? .secondary : .primary)

                chart(points, metric: metric, reversed: reversed)
                    .frame(height: 220)
            }
        }
        .card()
    }

    private func chart(_ points: [ChartPoints.Point], metric: ChartMetric, reversed: Bool) -> some View {
        Chart {
            ForEach(points) { p in
                let y = display(p.value, metric: metric)
                LineMark(x: .value("日期", p.date), y: .value("數值", y))
                    .foregroundStyle(Theme.green.opacity(0.6))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("日期", p.date), y: .value("數值", y))
                    .foregroundStyle(by: .value("類型", p.isMax ? "MAX" : "一般"))
                    .symbol(by: .value("類型", p.isMax ? "MAX" : "一般"))
                    .symbolSize(p.isMax ? 90 : 40)
            }
            if let selected {
                RuleMark(x: .value("日期", selected.date))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .chartForegroundStyleScale(["一般": Theme.green, "MAX": Theme.orange])
        .chartSymbolScale(["一般": .circle, "MAX": .diamond])
        .chartYScale(domain: .automatic(includesZero: false, reversed: reversed))
        .chartLegend(points.contains(where: \.isMax) ? .visible : .hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(.rect)
                    .onTapGesture { location in
                        if let p = nearest(points, x: location.x, proxy: proxy, geo: geo) {
                            onOpenSession(p.sessionID)
                        }
                    }
                    // 長按後拖曳才顯示數值，避免和上下捲動衝突
                    .gesture(
                        LongPressGesture(minimumDuration: 0.2)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                if case .second(true, let drag?) = value {
                                    selected = nearest(points, x: drag.location.x, proxy: proxy, geo: geo)
                                }
                            }
                            .onEnded { _ in selected = nil }
                    )
            }
        }
    }

    private func nearest(_ points: [ChartPoints.Point], x: CGFloat, proxy: ChartProxy, geo: GeometryProxy) -> ChartPoints.Point? {
        guard let plot = proxy.plotFrame else { return nil }
        let originX = geo[plot].origin.x
        guard let date: Date = proxy.value(atX: x - originX) else { return nil }
        return points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private func display(_ value: Double, metric: ChartMetric) -> Double {
        metric.isWeight || exercise.logType == .assisted ? unit.displayRounded(unit.fromKg(value)) : value
    }

    private func valueText(_ value: Double, metric: ChartMetric) -> String {
        if metric.isWeight || exercise.logType == .assisted { return unit.formatWithUnit(kg: value) }
        switch metric {
        case .reps: return "\(Int(value)) 下"
        case .seconds: return "\(Units.number(value)) 秒"
        case .speed: return "\(value.formatted(.number.precision(.fractionLength(1)))) km/h"
        case .incline: return "坡度 \(Units.number(value))%"
        case .minutes: return "\(Units.number(value)) 分"
        default: return Units.number(value)
        }
    }
}

// MARK: - (c) 強度換算表

private struct IntensityCard: View {
    let exercise: Exercise
    let sessions: [SessionSets]

    enum Base: String, CaseIterable, Identifiable {
        case estimate, lastMax, manual
        var id: String { rawValue }
        var title: String {
            switch self {
            case .estimate: "估算 1RM"
            case .lastMax: "最近一次 MAX"
            case .manual: "手動輸入"
            }
        }
    }

    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @AppStorage(RoundingSteps.barbellKgKey) private var barbellKg = RoundingSteps.barbellKgDefault
    @AppStorage(RoundingSteps.barbellLbsKey) private var barbellLbs = RoundingSteps.barbellLbsDefault
    @AppStorage(RoundingSteps.otherKgKey) private var otherKg = RoundingSteps.otherKgDefault
    @AppStorage(RoundingSteps.otherLbsKey) private var otherLbs = RoundingSteps.otherLbsDefault
    @State private var base: Base = .estimate
    @State private var manualText = ""

    private var step: Double {
        switch (exercise.equipment == .barbell, unit) {
        case (true, .kg): barbellKg
        case (true, .lbs): barbellLbs
        case (false, .kg): otherKg
        case (false, .lbs): otherLbs
        }
    }

    /// 基準 1RM（kg）
    private var baseKg: Double? {
        switch base {
        case .estimate:
            return PersonalRecords.estimated1RM(sessions)?.record.value
        case .lastMax:
            return sessions.reversed().lazy
                .compactMap { $0.sets.filter { $0.kind == .max && $0.isCompleted }.compactMap(\.weightKg).max() }
                .first
        case .manual:
            return Double(manualText.replacingOccurrences(of: ",", with: ".")).map(unit.toKg)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("強度換算表").font(.headline).foregroundStyle(.secondary)
            Picker("基準", selection: $base) {
                ForEach(Base.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if base == .manual {
                HStack {
                    TextField("1RM", text: $manualText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .padding(10)
                        .background(Theme.field, in: .rect(cornerRadius: 10))
                    Text(unit.symbol).foregroundStyle(.secondary)
                }
            }

            if let baseKg {
                Text("基準 \(unit.formatWithUnit(kg: baseKg)) · 進位每 \(Units.number(step)) \(unit.symbol)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(IntensityTable.rows(base1RMKg: baseKg, unit: unit, step: step)) { row in
                    HStack {
                        Text("\(row.percent)%")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .leading)
                        Text("\(Units.number(row.weight)) \(unit.symbol)")
                            .font(.body.weight(.semibold).monospacedDigit())
                        Spacer()
                        Text(row.purposes.joined(separator: "、"))
                            .font(.footnote)
                            .foregroundStyle(purposeColor(row.percent))
                    }
                }
            } else {
                Text(base == .manual ? "請輸入 1RM" : "沒有可用的紀錄")
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func purposeColor(_ percent: Int) -> Color {
        percent >= 85 ? Theme.red : percent >= 75 ? Theme.yellow : Theme.green
    }
}

// MARK: - (d) 同分類替代動作

private struct AlternativesCard: View {
    let exercise: Exercise
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var candidates: [Exercise]

    var body: some View {
        let others = candidates.filter { $0.category == exercise.category && $0 !== exercise }
        let list = Array(Recency.sortedByNeglect(others, lastDate: \.lastCompletedDate, name: \.name, untrainedLast: true).prefix(5))
        VStack(alignment: .leading, spacing: 12) {
            Text("同分類替代動作").font(.headline).foregroundStyle(.secondary)
            if list.isEmpty {
                Text("這個分類沒有其他動作").foregroundStyle(.secondary)
            }
            ForEach(Array(list.enumerated()), id: \.element.id) { index, other in
                if index > 0 { Divider().overlay(Theme.cardBorder) }
                NavigationLink {
                    ExerciseDetailView(exercise: other)
                } label: {
                    let days = Recency.daysSince(other.lastCompletedDate)
                    HStack {
                        Text(other.name).font(.body.weight(.semibold))
                        ForEach(other.tags) { Chip(text: $0.title) }
                        Spacer()
                        if let days {
                            Text(days == 0 ? "今天" : "上次 \(days) 天前")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Recency.staleness(days: days).color)
                        } else {
                            Chip(text: "未練過")
                        }
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }
}

/// 強度換算表的進位單位（設定頁可改）
enum RoundingSteps {
    static let barbellKgKey = "round.barbell.kg"
    static let barbellLbsKey = "round.barbell.lbs"
    static let otherKgKey = "round.other.kg"
    static let otherLbsKey = "round.other.lbs"
    static let barbellKgDefault = 2.5
    static let barbellLbsDefault = 5.0
    static let otherKgDefault = 1.0
    static let otherLbsDefault = 2.5
}
