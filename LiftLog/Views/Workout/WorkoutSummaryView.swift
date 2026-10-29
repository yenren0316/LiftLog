import SwiftUI
import SwiftData

/// 完成訓練後的摘要
struct WorkoutSummary: Identifiable {
    struct Line: Identifiable {
        var id = UUID()
        var name: String
        var completedSets: Int
        var summary: String
        var isNewRecord: Bool
    }

    var id = UUID()
    var title: String
    var duration: TimeInterval
    var lines: [Line]
    /// 這次刷新紀錄的動作（CHANGE_15 §4，和摘要頁同一個 NewRecords.find）
    var records: [NewRecords.Record]

    /// 在 finish 之後呼叫：新紀錄和這次訓練開始之前的紀錄比較
    @MainActor
    init(session: WorkoutSession, unit: WeightUnit) {
        title = session.title
        duration = (session.endedAt ?? .now).timeIntervalSince(session.startedAt)
        records = NewRecords.find(in: session)
        let recordIDs = Set(records.map(\.exerciseID))
        lines = session.orderedItems.compactMap { item in
            guard let exercise = item.exercise else { return nil }
            return Line(
                name: exercise.name,
                completedSets: item.completedSets.count,
                summary: item.summary(unit: unit),
                isNewRecord: recordIDs.contains(exercise.id)
            )
        }
    }
}

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    /// 畫面出現時變成 true：完成訓練的 success 觸覺，有新紀錄時獎盃同時彈一次（CHANGE_15 §4）
    @State private var appeared = false
    /// 選填的「今天體重」（CHANGE_07 D-2）
    @State private var weightText = ""
    @FocusState private var weightFocused: Bool
    @State private var confirmingOverwrite: BodyWeight?

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !summary.records.isEmpty {
                    NewRecordsCard(records: summary.records, unit: unit, bounces: appeared && !reduceMotion)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                    Text("訓練完成").font(.largeTitle.bold())
                    Text(summary.title).font(.title3).foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 0) {
                    stat(WorkoutSession.format(duration: summary.duration), "總時長")
                    stat(String(summary.lines.count), "動作")
                    stat(String(summary.lines.reduce(0) { $0 + $1.completedSets }), "組")
                }
                .card(padding: 16)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(summary.lines) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(line.name).font(.body.weight(.semibold))
                                if line.isNewRecord {
                                    Image(systemName: "trophy.fill").accessibilityLabel("新紀錄")
                                }
                                Spacer()
                                Text("\(line.completedSets) 組").foregroundStyle(Theme.textSecondary)
                            }
                            Text(line.summary).font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .card()

                HStack {
                    Label("今天體重", systemImage: "scalemass").font(.headline)
                    Text("選填").font(.caption).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    TextField(BodyWeightLog.existing(on: .now, in: context).map { unit.format(kg: $0.kg) } ?? "—", text: $weightText)
                        .keyboardType(.decimalPad)
                        .focused($weightFocused)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .frame(width: 90)
                    Text(unit.symbol).foregroundStyle(Theme.textSecondary)
                }
                .card(padding: 16)
                .id("weight")

                PrimaryButton(title: "完成", action: finish)
            }
            .padding(16)
        }
        // 輸入今天體重時捲到中間，不被鍵盤和鍵盤上的「完成」蓋住
        .onChange(of: weightFocused) { _, focused in
            guard focused else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation { proxy.scrollTo("weight", anchor: .center) }
            }
        }
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        // 完成訓練：success（強度交給系統，系統關掉震動時不震）
        .sensoryFeedback(.success, trigger: appeared) { _, shown in shown }
        .onAppear { appeared = true }
        #if DEBUG
        // 開發用：-focusWeight YES 直接輸入今天體重（截鍵盤的「完成」用）
        .task {
            if UserDefaults.standard.bool(forKey: "focusWeight") {
                try? await Task.sleep(for: .milliseconds(800))
                weightFocused = true
            }
        }
        #endif
        .alert("覆蓋今天的體重？", isPresented: Binding(get: { confirmingOverwrite != nil }, set: { if !$0 { confirmingOverwrite = nil } }),
               presenting: confirmingOverwrite) { existing in
            Button("覆蓋") {
                if let kg = weightKg { BodyWeightLog.save(kg: kg, on: .now, in: context) }
                onClose()
            }
            Button("取消", role: .cancel) {}
        } message: { existing in
            Text("今天已經有 \(unit.formatWithUnit(kg: existing.kg))，同一天只保留一筆。")
        }
    }

    /// 有填體重就記下來（同一天只保留一筆，已經有的先確認），然後關閉
    private func finish() {
        guard let kg = weightKg else { return onClose() }
        if let existing = BodyWeightLog.existing(on: .now, in: context), existing.kg != kg {
            confirmingOverwrite = existing
        } else {
            BodyWeightLog.save(kg: kg, on: .now, in: context)
            onClose()
        }
    }

    private var weightKg: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? unit.toKg($0) : nil }
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
            Text(title).font(.footnote).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 「新紀錄」區塊（完成畫面的最上方）：獎盃、每個刷新紀錄的動作、這次的估算 1RM、之前最好的估算 1RM。
/// 獎盃在畫面出現時彈一次（.symbolEffect(.bounce)）；系統開啟「減少動態效果」時不播
private struct NewRecordsCard: View {
    var records: [NewRecords.Record]
    var unit: WeightUnit
    var bounces: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("新紀錄").font(.title3.bold())
            } icon: {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .symbolEffect(.bounce, options: .nonRepeating, value: bounces)
            }
            ForEach(records) { record in
                HStack(alignment: .firstTextBaseline) {
                    Text(record.name).font(.body.weight(.semibold))
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("估算 1RM \(unit.formatWithUnit(kg: record.estimated1RM))")
                            .font(.body.weight(.semibold).monospacedDigit())
                        Text("之前 \(unit.formatWithUnit(kg: record.previous1RM))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("newRecords")
    }
}
