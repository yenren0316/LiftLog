import Foundation
import Testing
@testable import LiftLog

/// CHANGE_05 第 2 節：小工具快照
@MainActor
struct WidgetSnapshotTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func session(_ day: Int, _ region: Region, _ roles: [Role]) -> PlanHistory.Session {
        PlanHistory.Session(date: date(day), region: region, items: roles.map {
            PlanHistory.Item(exerciseID: UUID(), category: $0 == .cardio ? .cardio : .horizontalPush, role: $0)
        })
    }

    @Test func neverTrained() {
        let snapshot = WidgetSnapshot.make(history: PlanHistory([]), activeStartedAt: nil, theme: ThemeSettings())
        #expect(snapshot.lastSessionDate == nil && snapshot.lastRegion == nil)
        #expect(snapshot.daysSinceLast(at: date(25), calendar: calendar) == nil)
        #expect(snapshot.lastSummary(calendar: calendar) == nil)
        // 沒有紀錄時的建議：下半身、3 個動作、不做跑步機
        #expect(snapshot.suggestedRegion == .lower)
        #expect(snapshot.suggestedCount == 3)
        #expect(!snapshot.suggestsTreadmill)
        #expect(!snapshot.isInProgress && snapshot.startedAt == nil)
    }

    @Test func lastSessionAndTodaysSuggestion() {
        let history = PlanHistory([
            session(23, .upper, [.push, .pull, .cardio]),
            session(20, .lower, [.main, .unilateral, .core]),
        ])
        let snapshot = WidgetSnapshot.make(history: history, activeStartedAt: nil, theme: ThemeSettings())
        #expect(snapshot.lastSessionDate == date(23))
        #expect(snapshot.lastRegion == .upper)
        #expect(snapshot.lastSummary(calendar: calendar) == "上半身・10/23")
        // 和建立菜單的預設答案一致：部位相反、動作數同上次（不計有氧）、上次有跑步機就建議跑步機
        #expect(snapshot.suggestedRegion == .lower)
        #expect(snapshot.suggestedCount == 2)
        #expect(snapshot.suggestsTreadmill)
        #expect(snapshot.daysSinceLast(at: date(25, 8), calendar: calendar) == 2)
        #expect(WidgetSnapshot.daysText(2) == "2 天前")
    }

    @Test func daysCountCalendarDays() {
        var snapshot = WidgetSnapshot.make(history: PlanHistory([]), activeStartedAt: nil, theme: ThemeSettings())
        snapshot.lastSessionDate = date(24, 23, 30)
        #expect(snapshot.daysSinceLast(at: date(24, 23, 59), calendar: calendar) == 0)
        #expect(WidgetSnapshot.daysText(0) == "今天")
        // 過了午夜就算 1 天
        #expect(snapshot.daysSinceLast(at: date(25, 0, 10), calendar: calendar) == 1)
        // timeline 預先排好的午夜 entry
        #expect(snapshot.daysSinceLast(at: date(31, 0, 0), calendar: calendar) == 7)
        // 部位未指定時只顯示日期
        snapshot.lastRegion = .unspecified
        #expect(snapshot.lastSummary(calendar: calendar) == "10/24")
    }

    @Test func inProgress() {
        let started = date(25, 18, 5)
        let snapshot = WidgetSnapshot.make(history: PlanHistory([session(23, .upper, [.push])]),
                                           activeStartedAt: started, theme: ThemeSettings())
        #expect(snapshot.isInProgress)
        #expect(snapshot.startedAt == started)
        // 進行中仍保留上次已完成的訓練
        #expect(snapshot.lastSessionDate == date(23))
    }

    @Test func themeAndPalette() {
        let fixed = WidgetSnapshot.make(history: PlanHistory([]), activeStartedAt: nil,
                                        theme: ThemeSettings(theme: .warmSand))
        #expect(fixed.themeID == "warmSand" && fixed.darkThemeID == nil && fixed.lightThemeID == nil)
        #expect(WidgetSnapshot.palette(for: fixed, isDark: true) == AppTheme.warmSand.palette)

        let follow = WidgetSnapshot.make(history: PlanHistory([]), activeStartedAt: nil,
                                         theme: ThemeSettings(followSystem: true, dark: .pureBlack, light: .warmSand))
        #expect(follow.themeID == nil && follow.darkThemeID == "pureBlack" && follow.lightThemeID == "warmSand")
        #expect(WidgetSnapshot.palette(for: follow, isDark: true) == AppTheme.pureBlack.palette)
        #expect(WidgetSnapshot.palette(for: follow, isDark: false) == AppTheme.warmSand.palette)

        // 讀不到快照：深色用石墨橙、淺色用冷灰
        #expect(WidgetSnapshot.palette(for: nil, isDark: true) == AppTheme.graphiteOrange.palette)
        #expect(WidgetSnapshot.palette(for: nil, isDark: false) == AppTheme.coolGray.palette)
    }

    @Test func storeWritesOnlyWhenChanged() throws {
        let defaults = try #require(UserDefaults(suiteName: "WidgetSnapshotTests.\(UUID().uuidString)"))
        var snapshot = WidgetSnapshot.make(history: PlanHistory([]), activeStartedAt: nil, theme: ThemeSettings())
        #expect(WidgetSnapshotStore.save(snapshot, to: defaults))
        #expect(!WidgetSnapshotStore.save(snapshot, to: defaults))
        #expect(WidgetSnapshotStore.load(from: defaults) == snapshot)
        snapshot.isInProgress = true
        #expect(WidgetSnapshotStore.save(snapshot, to: defaults))
        #expect(WidgetSnapshotStore.load(from: defaults)?.isInProgress == true)
    }
}
