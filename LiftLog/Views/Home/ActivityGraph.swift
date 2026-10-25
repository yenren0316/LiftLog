import SwiftUI

/// 訓練日曆：每天一格，有練的日子亮起來，做越多動作越亮（類似 GitHub contribution graph）
struct ActivityGraph: View {
    /// 每天（startOfDay）做了幾個動作
    var days: [Date: Int]
    var weekCount = 53

    private let cell: CGFloat = 13
    private let gap: CGFloat = 4

    var body: some View {
        let calendar = Calendar.current
        let counts = days
        let weeks = ActivityCalendar.weeks(endingAt: .now, count: weekCount)
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: .now)) ?? .now
        let daysThisYear = counts.keys.filter { $0 >= yearStart }.count

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("訓練日曆").font(.headline).foregroundStyle(Theme.textSecondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("今年").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    Text(String(daysThisYear))
                        .font(.title3.bold().monospacedDigit()).foregroundStyle(Theme.accent)
                    Text("天").font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    monthLabels(weeks, calendar: calendar)
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(weeks.indices, id: \.self) { w in
                            VStack(spacing: gap) {
                                ForEach(0..<7, id: \.self) { d in
                                    square(for: weeks[w][d], counts: counts)
                                }
                            }
                        }
                    }
                }
            }
            .defaultScrollAnchor(.trailing)

            HStack(spacing: 4) {
                Spacer()
                Text("少").font(.caption2).foregroundStyle(Theme.textSecondary)
                ForEach(0...3, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3).fill(color(level: level)).frame(width: 10, height: 10)
                }
                Text("多").font(.caption2).foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }

    @ViewBuilder
    private func square(for day: Date?, counts: [Date: Int]) -> some View {
        if let day {
            RoundedRectangle(cornerRadius: 3)
                .fill(color(level: ActivityCalendar.level(for: counts[day] ?? 0)))
                .frame(width: cell, height: cell)
        } else {
            Color.clear.frame(width: cell, height: cell)
        }
    }

    /// 每個月第一次出現的那週標上月份
    private func monthLabels(_ weeks: [[Date?]], calendar: Calendar) -> some View {
        HStack(spacing: gap) {
            ForEach(weeks.indices, id: \.self) { w in
                let first = weeks[w].compactMap { $0 }.first
                let month = first.map { calendar.component(.month, from: $0) }
                let previous = w > 0 ? weeks[w - 1].compactMap { $0 }.first.map { calendar.component(.month, from: $0) } : nil
                Text(month != nil && month != previous ? "\(month!)月" : "")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize()
                    .frame(width: cell, alignment: .leading)
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
