import SwiftUI
import SwiftData
import Charts

/// 體重卡（歷程的統計，CHANGE_07 D-2）：最新體重、和 30 天前的差距、折線圖（含 7 日平均），單位跟隨全域設定
struct BodyWeightCard: View {
    @Query(sort: \BodyWeight.date) private var records: [BodyWeight]
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @State private var range: ChartRange = .sixMonths
    @State private var entry: BodyWeightEntryRequest?

    var body: some View {
        let entries = BodyWeightLog.perDay(records.map { BodyWeightLog.Entry(date: $0.date, kg: $0.kg) })
        let shown = BodyWeightLog.filter(entries, range: range)
        let average = BodyWeightLog.movingAverage(entries).filter { e in shown.contains { $0.date == e.date } }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("體重").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Button { entry = BodyWeightEntryRequest(date: .now) } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .accessibilityLabel("記錄體重")
                    .buttonStyle(.pressable)
                    .foregroundStyle(Theme.accent)
            }
            if let latest = entries.last {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(unit.formatWithUnit(kg: latest.kg)).font(.title.bold().monospacedDigit())
                    if let change = BodyWeightLog.change(entries) {
                        Text("近 30 天 \(change >= 0 ? "+" : "−")\(unit.format(kg: abs(change))) \(unit.symbol)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text(latest.date.shortDate).font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Picker("範圍", selection: $range.animation(.tap)) {
                    ForEach(ChartRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if shown.count >= 2 {
                    chart(shown, average: average)
                } else {
                    Text("這段期間的紀錄不足，無法畫圖").font(.subheadline).foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            } else {
                Text("還沒有體重紀錄。按右上角的＋記錄，或從健康 App 帶入。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .card(padding: 16)
        .sheet(item: $entry) { BodyWeightEntrySheet(date: $0.date) }
    }

    private func chart(_ entries: [BodyWeightLog.Entry], average: [BodyWeightLog.Entry]) -> some View {
        let values = entries.map { unit.fromKg($0.kg) }
        let low = (values.min() ?? 0) - 1, high = (values.max() ?? 0) + 1
        return Chart {
            ForEach(entries) { entry in
                LineMark(x: .value("日期", entry.date), y: .value("體重", unit.fromKg(entry.kg)), series: .value("線", "體重"))
                    .foregroundStyle(Theme.accent.opacity(0.45))
                PointMark(x: .value("日期", entry.date), y: .value("體重", unit.fromKg(entry.kg)))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(18)
            }
            ForEach(average) { entry in
                LineMark(x: .value("日期", entry.date), y: .value("體重", unit.fromKg(entry.kg)), series: .value("線", "7 日平均"))
                    .foregroundStyle(Theme.done)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartYScale(domain: low...high)
        .chartLegend(.hidden)
        .frame(height: 160)
        .overlay(alignment: .topTrailing) {
            Label("7 日平均", systemImage: "line.diagonal").font(.caption2).foregroundStyle(Theme.done)
        }
    }
}

/// 打開記錄體重的 sheet（日期預設今天；摘要浮窗帶那次訓練的日期）
struct BodyWeightEntryRequest: Identifiable {
    let id = UUID()
    var date: Date
}

/// 記錄體重的小 sheet：日期（預設今天）和體重；同一天已經有紀錄時，覆蓋前先確認。
/// 健康 App 可用時可以帶入最近 30 天的體重（多選；同一天已有紀錄的以 App 內的為準）
struct BodyWeightEntrySheet: View {
    @State var date: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @State private var text = ""
    @State private var confirmingOverwrite: BodyWeight?
    @State private var showingHealth = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 12) {
                    HStack {
                        Text("日期").foregroundStyle(Theme.textSecondary)
                        Spacer()
                        DatePicker("日期", selection: $date, in: ...Date.now, displayedComponents: .date).labelsHidden()
                    }
                    HStack {
                        Text("體重").foregroundStyle(Theme.textSecondary)
                        Spacer()
                        TextField("例如 70.5", text: $text)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .frame(width: 120)
                        Text(unit.symbol).foregroundStyle(Theme.textSecondary)
                    }
                    if let existing = BodyWeightLog.existing(on: date, in: context) {
                        Text("這天已經有 \(unit.formatWithUnit(kg: existing.kg))，儲存會覆蓋")
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .card()
                if HealthWorkouts.isAvailable {
                    PrimaryButton(title: "從健康 App 帶入", systemImage: "heart.text.square", prominent: false) {
                        showingHealth = true
                    }
                }
                Spacer()
                PrimaryButton(title: "儲存", isEnabled: kg != nil, action: save)
            }
            .padding(16)
            .screenBackground()
            .navigationTitle("記錄體重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .alert("覆蓋這天的體重？", isPresented: Binding(get: { confirmingOverwrite != nil }, set: { if !$0 { confirmingOverwrite = nil } }),
               presenting: confirmingOverwrite) { existing in
            Button("覆蓋") { write() }
            Button("取消", role: .cancel) {}
        } message: { existing in
            Text("\(date.shortDate) 已經有 \(unit.formatWithUnit(kg: existing.kg))，同一天只保留一筆。")
        }
        .sheet(isPresented: $showingHealth) { HealthBodyMassImport() }
    }

    private var kg: Double? {
        Double(text.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? unit.toKg($0) : nil }
    }

    private func save() {
        if let existing = BodyWeightLog.existing(on: date, in: context) {
            confirmingOverwrite = existing
        } else {
            write()
        }
    }

    private func write() {
        guard let kg else { return }
        BodyWeightLog.save(kg: kg, on: date, in: context)
        dismiss()
    }
}

/// 從健康 App 帶入最近 30 天的體重：可以多選；同一天 App 裡已經有紀錄的不能選（以 App 內的為準）
private struct HealthBodyMassImport: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @State private var samples: [HealthBodyMass]?
    @State private var selected: Set<UUID> = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Text(error).foregroundStyle(Theme.danger).listRowBackground(Theme.card)
                } else if let samples {
                    if samples.isEmpty {
                        Text("健康 App 裡最近 30 天沒有體重紀錄（或沒有開放讀取：設定 → 健康 → 資料存取與裝置 → LiftLog）。")
                            .foregroundStyle(Theme.textSecondary)
                            .listRowBackground(Theme.card)
                    }
                    ForEach(samples) { sample in
                        let taken = BodyWeightLog.existing(on: sample.date, in: context) != nil
                        Button {
                            if selected.contains(sample.id) { selected.remove(sample.id) } else { selected.insert(sample.id) }
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(sample.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(sample.id) ? Theme.accent : Theme.textSecondary)
                                VStack(alignment: .leading) {
                                    Text(unit.formatWithUnit(kg: sample.kg)).font(.body.weight(.semibold).monospacedDigit())
                                    Text("\(sample.date.shortDate)・\(sample.source)").font(.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                if taken { Chip(text: "App 內已有") }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.pressable)
                        .disabled(taken)
                        .listRowBackground(Theme.card)
                    }
                } else {
                    ProgressView().listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("從健康 App 帶入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("匯入（\(selected.count)）", action: importSelected).disabled(selected.isEmpty)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            try await HealthWorkouts.requestBodyMassAuthorization()
            samples = try await HealthWorkouts.recentBodyMass()
        } catch {
            self.error = "讀不到健康資料：\(error.localizedDescription)"
        }
    }

    /// 同一天有多筆時取最新的；同一天 App 裡已經有紀錄的跳過
    private func importSelected() {
        let chosen = (samples ?? []).filter { selected.contains($0.id) }
        let perDay = Dictionary(grouping: chosen) { Calendar.current.startOfDay(for: $0.date) }.values.compactMap { $0.max { $0.date < $1.date } }
        for sample in perDay where BodyWeightLog.existing(on: sample.date, in: context) == nil {
            BodyWeightLog.save(kg: sample.kg, on: sample.date, in: context)
        }
        dismiss()
    }
}
