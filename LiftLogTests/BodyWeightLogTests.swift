import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_07 D-2（T9）：體重同一天只保留一筆、7 日平均、和 30 天前比較
@MainActor
struct BodyWeightLogTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int = 8, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(for: LiftLogStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    @Test func savingTheSameDayOverwritesInsteadOfAdding() throws {
        let context = try makeContext()
        BodyWeightLog.save(kg: 72, on: date(20, 7), in: context, calendar: calendar)
        BodyWeightLog.save(kg: 71.4, on: date(20, 21), in: context, calendar: calendar)
        BodyWeightLog.save(kg: 71, on: date(21), in: context, calendar: calendar)

        let all = try context.fetch(FetchDescriptor<BodyWeight>(sortBy: [SortDescriptor(\.date)]))
        #expect(all.map(\.kg) == [71.4, 71])
        #expect(BodyWeightLog.existing(on: date(20, 23), in: context, calendar: calendar)?.kg == 71.4)
        #expect(BodyWeightLog.existing(on: date(22), in: context, calendar: calendar) == nil)
    }

    @Test func savingCleansUpOldDuplicatesOnThatDay() throws {
        let context = try makeContext()
        // 舊資料（例如從備份還原）同一天有兩筆
        context.insert(BodyWeight(date: date(20, 7), kg: 72))
        context.insert(BodyWeight(date: date(20, 9), kg: 72.2))
        try context.save()
        BodyWeightLog.save(kg: 71.8, on: date(20), in: context, calendar: calendar)
        let all = try context.fetch(FetchDescriptor<BodyWeight>())
        #expect(all.count == 1)
        #expect(all.first?.kg == 71.8)
    }

    @Test func perDayKeepsTheLatestRecordOfEachDay() {
        let entries = [BodyWeightLog.Entry(date: date(21), kg: 71),
                       BodyWeightLog.Entry(date: date(20, 7), kg: 72),
                       BodyWeightLog.Entry(date: date(20, 21), kg: 71.5)]
        #expect(BodyWeightLog.perDay(entries, calendar: calendar).map(\.kg) == [71.5, 71])
    }

    @Test func movingAverageUsesTheLastSevenDays() {
        // 10/1、10/4、10/7、10/8：10/8 的 7 日平均是 10/4、10/7、10/8（10/1 已經超過 7 天）
        let entries = [(1, 70.0), (4, 71.0), (7, 72.0), (8, 73.0)].map { BodyWeightLog.Entry(date: date($0.0), kg: $0.1) }
        let average = BodyWeightLog.movingAverage(entries, calendar: calendar)
        #expect(average.map(\.kg) == [70, 70.5, 71, 72])
    }

    @Test func changeComparesWithThirtyDaysAgo() {
        let now = date(26, 12)
        let entries = [BodyWeightLog.Entry(date: date(20, month: 9), kg: 74),
                       BodyWeightLog.Entry(date: date(26, month: 9), kg: 73.5),
                       BodyWeightLog.Entry(date: date(10), kg: 72.8),
                       BodyWeightLog.Entry(date: date(25), kg: 72)]
        // 30 天前是 9/26：用那天的 73.5
        let change = BodyWeightLog.change(entries, now: now, calendar: calendar)
        #expect(change.map { abs($0 - (-1.5)) < 0.001 } == true)
        // 30 天前沒有紀錄
        #expect(BodyWeightLog.change(Array(entries.suffix(2)), now: now, calendar: calendar) == nil)
        // 最新一筆本身就在 30 天前
        #expect(BodyWeightLog.change(Array(entries.prefix(2)), now: now, calendar: calendar) == nil)
    }

    @Test func filterByRange() {
        let now = date(26, 12)
        let entries = [BodyWeightLog.Entry(date: date(1, month: 3), kg: 75),
                       BodyWeightLog.Entry(date: date(1, month: 9), kg: 73)]
        #expect(BodyWeightLog.filter(entries, range: .threeMonths, now: now).map(\.kg) == [73])
        #expect(BodyWeightLog.filter(entries, range: .all, now: now).count == 2)
    }
}
