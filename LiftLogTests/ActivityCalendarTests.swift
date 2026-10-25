import Foundation
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

    @Test func levelsCapAtThree() {
        #expect([0, 1, 2, 3, 7].map(ActivityCalendar.level) == [0, 1, 2, 3, 3])
    }
}
