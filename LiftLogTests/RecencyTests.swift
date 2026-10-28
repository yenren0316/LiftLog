import Foundation
import Testing
@testable import LiftLog

struct RecencyTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // MARK: daysSince

    @Test func daysSinceNilIsNil() {
        #expect(Recency.daysSince(nil, now: date(2026, 10, 25), calendar: calendar) == nil)
    }

    @Test func sameDayIsZero() {
        #expect(Recency.daysSince(date(2026, 10, 25, 7), now: date(2026, 10, 25, 22), calendar: calendar) == 0)
    }

    @Test func countsCalendarDaysNotHours() {
        // 昨晚 23 點做的，今天凌晨 1 點看：只隔 2 小時，但算 1 天前
        #expect(Recency.daysSince(date(2026, 10, 24, 23), now: date(2026, 10, 25, 1), calendar: calendar) == 1)
    }

    @Test func spansMonthsAndLeapYear() {
        #expect(Recency.daysSince(date(2024, 2, 28), now: date(2024, 3, 1), calendar: calendar) == 2)
        #expect(Recency.daysSince(date(2025, 10, 25), now: date(2026, 10, 25), calendar: calendar) == 365)
    }

    @Test func futureDateClampsToZero() {
        #expect(Recency.daysSince(date(2026, 10, 30), now: date(2026, 10, 25), calendar: calendar) == 0)
    }

    // MARK: staleness

    @Test func stalenessThresholds() {
        #expect(Recency.staleness(days: nil) == .never)
        #expect(Recency.staleness(days: 0) == .fresh)
        #expect(Recency.staleness(days: 60) == .fresh)
        #expect(Recency.staleness(days: 61) == .stale)
        #expect(Recency.staleness(days: 180) == .stale)
        #expect(Recency.staleness(days: 181) == .cold)
    }

    // MARK: sortedByNeglect

    private struct Item {
        var name: String
        var last: Date?
    }

    private func sorted(_ items: [Item]) -> [String] {
        Recency.sortedByNeglect(items, lastDate: \.last, name: \.name).map(\.name)
    }

    @Test func neverDoneComesFirstThenOldest() {
        let items = [
            Item(name: "臥推", last: date(2026, 10, 20)),
            Item(name: "面拉", last: nil),
            Item(name: "深蹲", last: date(2025, 1, 7)),
            Item(name: "硬舉", last: date(2026, 5, 24)),
        ]
        #expect(sorted(items) == ["面拉", "深蹲", "硬舉", "臥推"])
    }

    @Test func tiesBreakByName() {
        let d = date(2026, 1, 1)
        let items = [
            Item(name: "C", last: d), Item(name: "A", last: d),
            Item(name: "Z", last: nil), Item(name: "B", last: nil),
        ]
        #expect(sorted(items) == ["B", "Z", "A", "C"])
    }

    @Test func emptyListStaysEmpty() {
        #expect(sorted([]).isEmpty)
    }

    // MARK: sections

    private struct Ex {
        var name: String
        var category: ExerciseCategory
        var last: Date?
    }

    @Test func sectionsFollowCategoryOrderAndHideEmpty() {
        let items = [
            Ex(name: "跑步機", category: .cardio, last: nil),
            Ex(name: "臥推", category: .horizontalPush, last: date(2026, 10, 20)),
            Ex(name: "上斜臥推", category: .horizontalPush, last: date(2025, 1, 1)),
            Ex(name: "深蹲", category: .kneeDominant, last: date(2026, 1, 1)),
            Ex(name: "面拉", category: .accessory, last: date(2026, 10, 24)),
        ]
        let sections = Recency.sections(items, category: \.category, lastDate: \.last, name: \.name)
        #expect(sections.map(\.category) == [.kneeDominant, .horizontalPush, .accessory, .cardio])
        #expect(!sections.contains { $0.category == .core })
        // 同一區內最久沒做的在前
        #expect(sections[1].items.map(\.name) == ["上斜臥推", "臥推"])
    }
}
