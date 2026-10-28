import SwiftUI

/// 今天的訓練日曆（CHANGE_08 §4、CHANGE_10 §2）：每天一格，顏色依那天的部位（同一天多次訓練依合併後的部位）：
/// 下肢 accent、上肢 upperBody、全身沿對角線各一半、有氧與其他（只有有氧，或只有核心、補強）textSecondary 40%。
/// 每一欄是一週，從週一開始；格子固定大小，週數依寬度剛好塞滿，不橫向捲動。
/// 整張卡是一個按鈕：點一下打開「訓練狀態」浮窗；格子本身沒有個別的點擊（CHANGE_09 的達標小點、標題列的
/// 「本週 N/目標・連續 N 週達標」和 CHANGE_08 的浮出標籤、拖曳震動都拿掉了）
struct TrainingCalendar: View {
    var days: [Date: StatsSnapshot.DayStat]
    /// 統計快照的「現在」：最後一欄是這一週（CHANGE_11 §2，跨過午夜重算後跟著移動）
    var now: Date
    /// 一次訓練都沒有時，格子下面的說明（取代圖例）
    var emptyText: String?
    var onOpen: () -> Void

    private let calendar = TrainingCount.weekCalendar()

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                Text("訓練日曆").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                GeometryReader { geo in
                    grid(ActivityCalendar.weeks(endingAt: now, count: CalendarGrid.weekCount(width: geo.size.width),
                                                calendar: calendar))
                }
                .frame(height: CalendarGrid.height)
                if days.isEmpty, let emptyText {
                    Text(emptyText).font(.footnote).foregroundStyle(Theme.textSecondary)
                } else {
                    RegionLegend()
                }
            }
            .padding(16)
        }
        // 整張卡都能點，按下時換成按壓色（CHANGE_10 §4）
        .buttonStyle(.tapCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("訓練日曆")
        .accessibilityHint("打開訓練狀態")
        .accessibilityAddTraits(.isButton)
    }

    private func grid(_ weeks: [[Date?]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            monthLabels(weeks)
                .padding(.bottom, CalendarGrid.monthRow - CalendarGrid.monthLabel)
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
                    .frame(width: CalendarGrid.cell, height: CalendarGrid.monthLabel, alignment: .leading)
            }
        }
    }
}
