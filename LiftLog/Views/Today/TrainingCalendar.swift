import SwiftUI

/// 今天的訓練日曆（CHANGE_08 §4）：每天一格，顏色依那天的部位（同一天多次訓練依合併後的部位）：
/// 下肢 accent、上肢 upperBody、全身沿對角線各一半、有氧與其他（只有有氧，或只有核心、補強）textSecondary 40%。格子固定大小，週數依寬度剛好塞滿，不橫向捲動。
/// 點一下有訓練的那天：格子上方浮出「10/23 週五・下肢最大肌力・深蹲」，2 秒後消失；
/// 按住拖曳：標籤跟著手指即時更新，每換一格震一下（selection），放開就消失。沒有任何導向
struct TrainingCalendar: View {
    var days: [Date: StatsSnapshot.DayStat]
    /// 標題列右邊的「本週 N 次」
    var weekSessions: Int
    /// 一次訓練都沒有時，格子下面的說明（取代圖例）
    var emptyText: String?

    /// 標籤要顯示的那一天
    @State private var peek: Date?
    /// 拖曳中手指下的那一格（換格時震動）
    @State private var dragCell: Date?
    @State private var hideTask: Task<Void, Never>?
    @State private var labelWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("訓練日曆").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("本週 \(weekSessions) 次").font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
            }
            GeometryReader { geo in
                let weeks = ActivityCalendar.weeks(endingAt: .now, count: CalendarGrid.weekCount(width: geo.size.width),
                                                   calendar: TrainingCount.weekCalendar())
                grid(weeks)
                    .contentShape(.rect)
                    .gesture(SpatialTapGesture().onEnded { value in
                        show(CalendarGrid.date(at: value.location, in: weeks))
                        hide(after: .seconds(2))
                    })
                    // 短按住才開始拖曳，捲動畫面不受影響
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.2)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            guard case .second(true, let drag?) = value else { return }
                            hideTask?.cancel()
                            let day = CalendarGrid.date(at: drag.location, in: weeks)
                            if day != dragCell { dragCell = day }
                            show(day)
                        }
                        .onEnded { _ in
                            dragCell = nil
                            peek = nil
                        })
                    .overlay(alignment: .topLeading) { peekLabel(weeks, width: geo.size.width) }
            }
            .frame(height: CalendarGrid.height)
            if days.isEmpty, let emptyText {
                Text(emptyText).font(.footnote).foregroundStyle(Theme.textSecondary)
            } else {
                RegionLegend()
            }
        }
        .card(padding: 16)
        .sensoryFeedback(.selection, trigger: dragCell) { _, new in new != nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("訓練日曆，本週 \(weekSessions) 次")
        #if DEBUG
        // 開發用：-calendarPeek 2026-10-24 顯示那天的標籤，而且不會自動消失（截圖用）
        .task {
            if let raw = UserDefaults.standard.string(forKey: "calendarPeek"),
               let day = try? Date(raw, strategy: .iso8601.year().month().day().dateSeparator(.dash)) {
                peek = Calendar.current.startOfDay(for: day)
            }
        }
        #endif
    }

    private func grid(_ weeks: [[Date?]]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            monthLabels(weeks)
            HStack(alignment: .top, spacing: CalendarGrid.gap) {
                ForEach(weeks.indices, id: \.self) { w in
                    VStack(spacing: CalendarGrid.gap) {
                        ForEach(0..<7, id: \.self) { d in square(weeks[w][d]) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func square(_ day: Date?) -> some View {
        let shape = RoundedRectangle(cornerRadius: CalendarGrid.cell / 4)
        Group {
            if let day {
                if let region = days[day]?.region {
                    shape.fill(region.fill)
                        .overlay { if day == peek { shape.stroke(Theme.textPrimary, lineWidth: 1.5) } }
                } else {
                    shape.fill(Theme.field)
                }
            } else {
                Color.clear
            }
        }
        .frame(width: CalendarGrid.cell, height: CalendarGrid.cell)
    }

    /// 每個月第一次出現的那週標上月份；下個月不到 3 週就開始時（例如最左邊不完整的月份）不標，避免字疊在一起
    private func monthLabels(_ weeks: [[Date?]]) -> some View {
        let calendar = Calendar.current
        let months = weeks.map { $0.compactMap { $0 }.first.map { calendar.component(.month, from: $0) } }
        let starts = months.indices.filter { $0 == 0 || months[$0] != months[$0 - 1] }
        let shown = Set(starts.enumerated().compactMap { i, w in
            i + 1 < starts.count && starts[i + 1] - w < 3 ? nil : w
        })
        return HStack(spacing: CalendarGrid.gap) {
            ForEach(weeks.indices, id: \.self) { w in
                Text(shown.contains(w) ? months[w].map { "\($0)月" } ?? "" : "")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize()
                    .frame(width: CalendarGrid.cell, height: 14, alignment: .leading)
            }
        }
    }

    /// 浮在那一格上方的標籤（最上面兩列上方沒有空間，改放在格子下方，不蓋到標題列）；左右不超出日曆
    @ViewBuilder
    private func peekLabel(_ weeks: [[Date?]], width: CGFloat) -> some View {
        if let peek, let text = CalendarGrid.peekText(day: peek, titles: days[peek]?.titles ?? []),
           let week = weeks.firstIndex(where: { $0.contains(peek) }),
           let day = weeks[week].firstIndex(of: peek) {
            let origin = CalendarGrid.origin(week: week, day: day)
            let center = origin.x + CalendarGrid.cell / 2
            let x = min(max(center - labelWidth / 2, 0), max(width - labelWidth, 0))
            let above = origin.y - 34
            PeekLabel(text: text)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { labelWidth = $0 }
                .offset(x: x, y: above >= 0 ? above : origin.y + CalendarGrid.cell + 6)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    /// 只有有訓練的日子顯示標籤
    private func show(_ day: Date?) {
        withAnimation(.tap) {
            peek = day.flatMap { days[$0]?.region == nil ? nil : $0 }
        }
    }

    private func hide(after delay: Duration) {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            withAnimation(.tap) { peek = nil }
        }
    }
}
