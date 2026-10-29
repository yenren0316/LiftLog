import SwiftUI
import SwiftData
import Charts

/// 數據分頁：個人紀錄、折線圖、強度換算表
struct ExerciseDataTab: View {
    let exercise: Exercise
    var onOpenSession: (UUID) -> Void

    var body: some View {
        let sessions = exercise.sessionSets
        VStack(alignment: .leading, spacing: 20) {
            RecordsCard(exercise: exercise, sessions: sessions, onOpenSession: onOpenSession)
            TrendChartCard(exercise: exercise, sessions: sessions)
            if exercise.logType == .weight {
                IntensityCard(exercise: exercise, sessions: sessions)
            }
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
            if records.isEmpty {
                Text(exercise.logType == .cardio ? "有氧沒有個人紀錄，請看下方圖表。" : "還沒有紀錄")
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                if index > 0 { Divider().overlay(Theme.separator) }
                Button { onOpenSession(record.sessionID) } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.title).font(.body.weight(.semibold))
                            Text(record.date.shortDate + (record.caption.map { " · \($0)" } ?? ""))
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Text(valueText(record))
                            .font(.title3.bold().monospacedDigit())
                    }
                    .tapRowInset()
                }
                .buttonStyle(.tapRow)
                .tapRowOutset()
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

/// 趨勢折線圖：選取和其他圖表一樣（CHANGE_11 §5），點一下浮出那一點的數字，2 秒後消失；
/// 不再有「打開這次訓練」，要看某一次訓練從「歷史」分頁打開
private struct TrendChartCard: View {
    let exercise: Exercise
    let sessions: [SessionSets]

    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @State private var range: ChartRange = .oneYear
    @State private var chosenMetric: ChartMetric?
    /// 點一下或按住拖曳選取的日期；選到最接近的那一點
    @State private var selectedDate: Date?

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
                Text("趨勢").font(.headline).foregroundStyle(Theme.textSecondary)
                if reversed {
                    Text("越低越好 ↑").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            let options = ChartMetric.options(for: logType)
            if !options.isEmpty {
                Picker("指標", selection: Binding(get: { metric }, set: { chosenMetric = $0 }).animation(.tap)) {
                    ForEach(options) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Picker("範圍", selection: $range.animation(.tap)) {
                ForEach(ChartRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if points.count < 2 {
                Text("紀錄不足，無法畫圖")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                let selected = selectedDate.flatMap { nearest(points, to: $0) }
                chart(points, selected: selected, metric: metric, reversed: reversed)
                    .frame(height: 220)
                    .accessibilityIdentifier("trendChart")
                    .accessibilityValue(selected.map { label($0, metric: metric) } ?? "")
            }
        }
        .card()
    }

    private func chart(_ points: [ChartPoints.Point], selected: ChartPoints.Point?, metric: ChartMetric, reversed: Bool) -> some View {
        Chart {
            ForEach(points) { p in
                let y = display(p.value, metric: metric)
                LineMark(x: .value("日期", p.date), y: .value("數值", y))
                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("日期", p.date), y: .value("數值", y))
                    .foregroundStyle(by: .value("類型", p.isMax ? "MAX" : "一般"))
                    .symbol(by: .value("類型", p.isMax ? "MAX" : "一般"))
                    .symbolSize(p.isMax ? 90 : 40)
            }
            if let selected {
                RuleMark(x: .value("日期", selected.date))
                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
                    .annotation(position: .overlay, alignment: .top, spacing: 0,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        PeekLabel(text: label(selected, metric: metric))
                    }
            }
        }
        // 一般和 MAX 用形狀區分（圓、菱形），顏色都是中性的（CHANGE_13 §3）
        .chartForegroundStyleScale(["一般": Theme.textPrimary, "MAX": Theme.textPrimary])
        .chartSymbolScale(["一般": .circle, "MAX": .diamond])
        .chartYScale(domain: .automatic(includesZero: false, reversed: reversed))
        .chartLegend(points.contains(where: \.isMax) ? .visible : .hidden)
        // 點一下浮出數字 2 秒；按住 0.2 秒後拖曳跟著手指，放開後 2 秒消失；上下滑交給捲動
        .chartDateSelection($selectedDate)
    }

    /// 浮出的數字：「10/20・93.5 kg」
    private func label(_ point: ChartPoints.Point, metric: ChartMetric) -> String {
        "\(point.date.formatted(.dateTime.month(.defaultDigits).day()))・\(valueText(point.value, metric: metric))"
    }

    private func nearest(_ points: [ChartPoints.Point], to date: Date) -> ChartPoints.Point? {
        points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
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

    /// 設定頁的進位（@AppStorage 讓改設定時重畫）
    private var step: Double {
        _ = (barbellKg, barbellLbs, otherKg, otherLbs)
        return RoundingSteps.step(equipment: exercise.equipment, unit: unit)
    }

    /// 基準 1RM（kg）
    private var baseKg: Double? {
        switch base {
        case .estimate:
            return IntensityTable.estimatedBase1RMKg(sessions)
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
            Text("強度換算表").font(.headline).foregroundStyle(Theme.textSecondary)
            Picker("基準", selection: $base.animation(.tap)) {
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
                    Text(unit.symbol).foregroundStyle(Theme.textSecondary)
                }
            }

            if let baseKg {
                Text("基準 \(unit.formatWithUnit(kg: baseKg)) · 進位每 \(Units.number(step)) \(unit.symbol)")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                ForEach(IntensityTable.rows(base1RMKg: baseKg, unit: unit, step: step)) { row in
                    HStack {
                        Text("\(row.percent)%")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 48, alignment: .leading)
                        Text("\(Units.number(row.weight)) \(unit.symbol)")
                            .font(.body.weight(.semibold).monospacedDigit())
                        Spacer()
                        Text(row.purposes.joined(separator: "、"))
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            } else {
                Text(base == .manual ? "請輸入 1RM" : "沒有可用的紀錄")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }
}
