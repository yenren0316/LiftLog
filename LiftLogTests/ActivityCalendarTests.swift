import Foundation
import CoreGraphics
import Testing
@testable import LiftLog

struct ActivityCalendarTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        c.firstWeekday = 2   // 週一開始
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func dailyCountsGroupByDay() {
        let counts = ActivityCalendar.dailyCounts(
            [date(2026, 10, 24, 8), date(2026, 10, 24, 21), date(2026, 10, 25)], calendar: calendar
        )
        #expect(counts[calendar.startOfDay(for: date(2026, 10, 24))] == 2)
        #expect(counts[calendar.startOfDay(for: date(2026, 10, 25))] == 1)
    }

    @Test func weeksEndWithTodayAndBlankFuture() {
        // 2026/10/22 是週四
        let weeks = ActivityCalendar.weeks(endingAt: date(2026, 10, 22, 18), count: 3, calendar: calendar)
        #expect(weeks.count == 3)
        #expect(weeks.allSatisfy { $0.count == 7 })
        let last = weeks[2]
        #expect(last[0] == calendar.startOfDay(for: date(2026, 10, 19)))  // 週一
        #expect(last[3] == calendar.startOfDay(for: date(2026, 10, 22)))  // 今天
        #expect(last[4] == nil)                                            // 明天之後空白
        #expect(weeks[0][0] == calendar.startOfDay(for: date(2026, 10, 5)))
    }

    /// CHANGE_08 T4：點或拖曳的位置換成那一天
    @Test func gridPositionsMapToDates() {
        let weeks = ActivityCalendar.weeks(endingAt: date(2026, 10, 22, 18), count: 3, calendar: calendar)
        let step = CalendarGrid.cell + CalendarGrid.gap
        func point(_ week: Int, _ day: Int, dx: CGFloat = 6, dy: CGFloat = 6) -> CGPoint {
            CGPoint(x: CGFloat(week) * step + dx, y: CalendarGrid.monthRow + CGFloat(day) * step + dy)
        }
        // 每一格的中間
        #expect(CalendarGrid.date(at: point(0, 0), in: weeks) == calendar.startOfDay(for: date(2026, 10, 5)))
        #expect(CalendarGrid.date(at: point(2, 3), in: weeks) == calendar.startOfDay(for: date(2026, 10, 22)))
        #expect(CalendarGrid.date(at: point(1, 6), in: weeks) == calendar.startOfDay(for: date(2026, 10, 18)))
        // 格子右邊和下面的空隙算前一格
        #expect(CalendarGrid.date(at: point(1, 2, dx: CalendarGrid.cell + 1, dy: CalendarGrid.cell + 1), in: weeks)
                == calendar.startOfDay(for: date(2026, 10, 14)))
        // 今天之後的空白、月份那一列、超出範圍
        #expect(CalendarGrid.date(at: point(2, 4), in: weeks) == nil)
        #expect(CalendarGrid.date(at: CGPoint(x: 6, y: 5), in: weeks) == nil)
        #expect(CalendarGrid.date(at: point(3, 0), in: weeks) == nil)
        #expect(CalendarGrid.date(at: point(0, 7), in: weeks) == nil)
        #expect(CalendarGrid.date(at: CGPoint(x: -1, y: 30), in: weeks) == nil)
        // 格子的左上角和位置對得起來
        let origin = CalendarGrid.origin(week: 2, day: 3)
        #expect(CalendarGrid.cell(at: CGPoint(x: origin.x + 1, y: origin.y + 1), weeks: 3)! == (2, 3))
        // 週數依寬度：340 pt 放得下 22 週
        #expect(CalendarGrid.weekCount(width: 340) == 22)
        #expect(CalendarGrid.weekCount(width: 5) == 1)
    }

    @Test func peekTextForOneOrMoreSessions() {
        let friday = calendar.startOfDay(for: date(2026, 10, 23))
        #expect(CalendarGrid.peekText(day: friday, titles: ["下肢最大肌力・深蹲"], calendar: calendar) == "10/23 週五・下肢最大肌力・深蹲")
        let saturday = calendar.startOfDay(for: date(2026, 10, 24))
        #expect(CalendarGrid.peekText(day: saturday, titles: ["有氧", "上肢訓練"], calendar: calendar) == "10/24 週六・2 次訓練")
        #expect(CalendarGrid.peekText(day: saturday, titles: [], calendar: calendar) == nil)
        #expect(CalendarGrid.peekText(day: calendar.startOfDay(for: date(2026, 10, 25)), titles: ["有氧"], calendar: calendar)
                == "10/25 週日・有氧")
    }

    @Test func levelsCapAtThree() {
        #expect([0, 1, 2, 3, 7].map(ActivityCalendar.level) == [0, 1, 2, 3, 3])
    }
}
