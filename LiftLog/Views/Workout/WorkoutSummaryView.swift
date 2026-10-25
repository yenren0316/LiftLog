import SwiftUI

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

    var body: some View {
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

                Button(action: onClose) {
                    Text("完成")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Theme.accent, in: .capsule)
                }
                .buttonStyle(.pressable)
            }
            .padding(16)
        }
        .screenBackground()
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
