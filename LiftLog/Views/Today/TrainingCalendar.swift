import SwiftUI
import SwiftData

/// 訓練日曆：每天一格，有練的日子亮起來，做越多動作越亮。不橫向捲動：
/// - fit：格子固定大小，週數依寬度剛好塞滿（「今天」）
/// - year：固定一整年（53 週），格子依寬度縮放（歷程的統計）
/// 點有訓練的那天呼叫 onSelectDay（打開摘要浮窗）
struct TrainingCalendar: View {
    enum Mode {
        case fit, year
    }

    var days: [Date: StatsSnapshot.DayStat]
    var mode: Mode = .fit
    var title = "訓練日曆"
    /// 標題列右邊的說明（例如「本週 2 次・近 12 週平均 2.5 次」）
    var caption: String?
    /// 一次訓練都沒有時，格子下面的說明
    var emptyText: String?
    var onSelectDay: (StatsSnapshot.DayStat) -> Void

    private static let fitCell: CGFloat = 12
    private static let fitGap: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                if let caption {
                    Text(caption).font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                }
            }
            switch mode {
            case .fit:
                GeometryReader { geo in
                    let count = max(1, Int((geo.size.width + Self.fitGap) / (Self.fitCell + Self.fitGap)))
                    grid(weeks: count, cell: Self.fitCell, gap: Self.fitGap)
                }
                .frame(height: Self.height(cell: Self.fitCell, gap: Self.fitGap))
            case .year:
                // 53 週＋52 個間隔（間隔 = 格子的 1/4）；高度依寬度算
                YearHeightLayout {
                    GeometryReader { geo in
                        let cell = YearHeightLayout.cell(width: geo.size.width)
                        grid(weeks: 53, cell: cell, gap: cell * 0.25)
                    }
                }
            }
            if days.isEmpty, let emptyText {
                Text(emptyText).font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
        .card(padding: 16)
    }

    /// 月份列＋7 列格子
    private static func height(cell: CGFloat, gap: CGFloat) -> CGFloat {
        14 + 4 + 7 * cell + 6 * gap
    }

    private func grid(weeks count: Int, cell: CGFloat, gap: CGFloat) -> some View {
        let calendar = Calendar.current
        let weeks = ActivityCalendar.weeks(endingAt: .now, count: count)
        return VStack(alignment: .leading, spacing: 4) {
            monthLabels(weeks, cell: cell, gap: gap, calendar: calendar)
            HStack(alignment: .top, spacing: gap) {
                ForEach(weeks.indices, id: \.self) { w in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { d in
                            square(weeks[w][d], cell: cell)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func square(_ day: Date?, cell: CGFloat) -> some View {
        if let day {
            let stat = days[day]
            let shape = RoundedRectangle(cornerRadius: cell / 4)
                .fill(color(level: ActivityCalendar.level(for: stat?.exerciseCount ?? 0)))
                .frame(width: cell, height: cell)
            if let stat, !stat.sessionIDs.isEmpty {
                Button { onSelectDay(stat) } label: { shape }
                    .buttonStyle(.pressable(scale: 0.8))
                    .accessibilityLabel(day.formatted(date: .abbreviated, time: .omitted))
            } else {
                shape
            }
        } else {
            Color.clear.frame(width: cell, height: cell)
        }
    }

    /// 每個月第一次出現的那週標上月份；下個月不到 3 週就開始時（例如最左邊不完整的月份）不標，避免字疊在一起
    private func monthLabels(_ weeks: [[Date?]], cell: CGFloat, gap: CGFloat, calendar: Calendar) -> some View {
        let months = weeks.map { $0.compactMap { $0 }.first.map { calendar.component(.month, from: $0) } }
        let starts = months.indices.filter { $0 == 0 || months[$0] != months[$0 - 1] }
        let shown = Set(starts.enumerated().compactMap { i, w in
            i + 1 < starts.count && starts[i + 1] - w < 3 ? nil : w
        })
        return HStack(spacing: gap) {
            ForEach(weeks.indices, id: \.self) { w in
                let label = shown.contains(w) ? months[w].map { mode == .year ? "\($0)" : "\($0)月" } : nil
                Text(label ?? "")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize()
                    .frame(width: cell, height: 14, alignment: .leading)
            }
        }
    }

    private func color(level: Int) -> Color {
        switch level {
        case 0: Theme.field
        case 1: Theme.accent.opacity(0.4)
        case 2: Theme.accent.opacity(0.7)
        default: Theme.accent
        }
    }
}

/// 一整年的日曆：寬度給多少，格子就縮放到剛好 53 週，高度跟著算
private struct YearHeightLayout: Layout {
    static func cell(width: CGFloat) -> CGFloat {
        width / (53 + 52 * 0.25)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 340
        let cell = Self.cell(width: width)
        return CGSize(width: width, height: 14 + 4 + 7 * cell + 6 * cell * 0.25)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// 點日曆上有訓練的那天（「今天」和歷程的統計共用）：一次就打開摘要浮窗，多次先列出來讓使用者選
struct DaySessionChooser: ViewModifier {
    @Binding var choices: [WorkoutSession]
    @Environment(WorkoutCoordinator.self) private var coordinator

    func body(content: Content) -> some View {
        content.confirmationDialog("這天有 \(choices.count) 次訓練", isPresented: Binding(
            get: { !choices.isEmpty }, set: { if !$0 { choices = [] } }
        ), titleVisibility: .visible) {
            ForEach(choices) { session in
                Button("\(session.startedAt.formatted(date: .omitted, time: .shortened))　\(session.title)") {
                    coordinator.showSummary(of: session)
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    /// 那天的訓練：一次就直接打開，多次放進 choices
    @MainActor
    static func open(_ day: StatsSnapshot.DayStat, context: ModelContext, coordinator: WorkoutCoordinator,
                     choices: inout [WorkoutSession]) {
        let sessions = day.sessionIDs.compactMap { id in
            try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })).first
        }
        if sessions.count == 1 {
            coordinator.showSummary(of: sessions[0])
        } else if sessions.count > 1 {
            choices = sessions
        }
    }
}
