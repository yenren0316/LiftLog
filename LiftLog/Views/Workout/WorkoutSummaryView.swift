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

    /// 在 finish 之後呼叫：新紀錄比較的是這次以外的所有歷史
    @MainActor
    init(session: WorkoutSession, unit: WeightUnit) {
        title = session.title
        duration = (session.endedAt ?? .now).timeIntervalSince(session.startedAt)
        lines = session.orderedItems.compactMap { item in
            guard let exercise = item.exercise else { return nil }
            let mine = item.completedSets.map(\.values)
            let history = exercise.sessionItems
                .filter { $0 !== item }
                .flatMap { $0.completedSets.map(\.values) }
            return Line(
                name: exercise.name,
                completedSets: mine.count,
                summary: item.summary(unit: unit),
                isNewRecord: SetLogic.isNewRecord(session: mine, history: history, logType: exercise.logType)
            )
        }
    }
}

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    /// 選填的「今天體重」（CHANGE_07 D-2）
    @State private var weightText = ""
    @FocusState private var weightFocused: Bool
    @State private var confirmingOverwrite: BodyWeight?

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.accent)
                    Text("訓練完成").font(.largeTitle.bold())
                    Text(summary.title).font(.title3).foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 0) {
                    stat(WorkoutSession.format(duration: summary.duration), "總時長")
                    stat(String(summary.lines.count), "動作")
                    stat(String(summary.lines.reduce(0) { $0 + $1.completedSets }), "組")
                }
                .card(padding: 16)

                let records = summary.lines.filter(\.isNewRecord)
                if !records.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("新紀錄", systemImage: "trophy.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.warning)
                        ForEach(records) { line in
                            HStack {
                                Text(line.name).font(.body.weight(.semibold))
                                Spacer()
                                Text(line.summary).foregroundStyle(Theme.warning)
                            }
                        }
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(summary.lines) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(line.name).font(.body.weight(.semibold))
                                if line.isNewRecord {
                                    Image(systemName: "trophy.fill").foregroundStyle(Theme.warning)
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
                .foregroundStyle(Theme.accent)
            Text(title).font(.footnote).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
