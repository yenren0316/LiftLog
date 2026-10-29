import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_11 §2：日期改變時重算統計快照（回到前景而且日期不同、跨過午夜、時區或系統時間改變）
@MainActor
struct StatsRefreshTests {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func foregroundRecomputesOnlyWhenTheDayChanged() {
        // 23:59 算過，00:01 回到前景：日期不同，重算
        #expect(StatsRefresh.needsRecompute(.foreground, computedAt: date(11, 1, 23, 59), now: date(11, 2, 0, 1), calendar: calendar))
        // 同一天回到前景：不重算
        #expect(!StatsRefresh.needsRecompute(.foreground, computedAt: date(11, 2, 0, 1), now: date(11, 2, 22, 30), calendar: calendar))
        // 還沒算過：一律算
        #expect(StatsRefresh.needsRecompute(.foreground, computedAt: nil, now: date(11, 2, 9), calendar: calendar))
        // 跨過午夜、時區或系統時間改變：一律重算
        #expect(StatsRefresh.needsRecompute(.dayChanged, computedAt: date(11, 2, 0, 0), now: date(11, 2, 0, 0), calendar: calendar))
        #expect(StatsRefresh.needsRecompute(.timeChanged, computedAt: date(11, 2, 9), now: date(11, 2, 9), calendar: calendar))
    }

    /// 統計快取：週日 23:59 有一次訓練，週一 00:01 回到前景要重算：本週歸零、上次「0 天前」變成「1 天前」
    @Test func sundayToMondayResetsTheWeek() throws {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        context.insert(squat)
        // 2026/11/1 是週日
        let sunday = date(11, 1, 19)
        let session = WorkoutSession(startedAt: sunday, endedAt: sunday.addingTimeInterval(3600), dayType: .meLower)
        context.insert(session)
        let item = SessionExercise(session: session, exercise: squat, order: 0, role: .maxEffort)
        context.insert(item)
        context.insert(SetRecord(sessionExercise: item, order: 0, weightKg: 100, reps: 3, isCompleted: true, completedAt: sunday))
        try context.save()

        let cache = StatsCache()
        cache.fixedCalendar = calendar
        cache.start(context: context, now: date(11, 1, 23, 59))
        #expect(cache.snapshot.trainingStatus.thisWeek.days == 1)
        #expect(cache.snapshot.trainingStatus.thisWeek.sets == 1)
        let row = try #require(cache.snapshot.trainingStatus.rotation.first { $0.dayType == .meLower })
        #expect(TrainingStatus.daysAgo(try #require(row.lastDate), now: cache.snapshot.now, calendar: calendar) == 0)

        // 同一天回到前景：不重算（快照的時間不變）
        cache.refresh(.foreground, now: date(11, 1, 23, 59) + 30)
        #expect(cache.snapshot.now == date(11, 1, 23, 59))

        // 週一 00:01 回到前景：重算
        let monday = date(11, 2, 0, 1)
        cache.refresh(.foreground, now: monday)
        #expect(cache.snapshot.now == monday)
        #expect(cache.snapshot.trainingStatus.thisWeek == TrainingStatus.Period())
        // 上週同期是上週一到上週一（含當天），週日的訓練不在裡面
        #expect(cache.snapshot.trainingStatus.lastWeek.days == 0)
        #expect(TrainingStatus.daysAgo(try #require(row.lastDate), now: cache.snapshot.now, calendar: calendar) == 1)
        #expect(Recency.daysSince(cache.snapshot.categoryLastDates[.kneeDominant], now: cache.snapshot.now, calendar: calendar) == 1)

        // App 開著時跨過午夜（NSCalendarDayChanged）：照樣重算
        let tuesday = date(11, 3, 0, 0)
        cache.refresh(.dayChanged, now: tuesday)
        #expect(cache.snapshot.now == tuesday)
        #expect(Recency.daysSince(cache.snapshot.categoryLastDates[.kneeDominant], now: cache.snapshot.now, calendar: calendar) == 2)
    }

    @Test func fakeNowParsesWithAndWithoutTimeZone() {
        #expect(AppClock.parse("2026-11-02T00:05:00+08:00") == date(11, 2, 0, 5))
        #expect(AppClock.parse("2026-11-02T00:05:00", timeZone: calendar.timeZone) == date(11, 2, 0, 5))
        #expect(AppClock.parse("not a date") == nil)
    }
}
