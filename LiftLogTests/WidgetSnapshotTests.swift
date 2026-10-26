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

    private func session(_ day: Int, _ region: Region, _ roles: [Role], dayType: DayType? = nil) -> PlanHistory.Session {
        PlanHistory.Session(date: date(day), region: region, dayType: dayType, items: roles.map {
            PlanHistory.Item(exerciseID: UUID(), category: $0 == .cardio ? .cardio : .horizontalPush, role: $0)
        })
    }

    @Test func neverTrained() {
        let snapshot = WidgetSnapshot.make(history: PlanHistory([]), activeStartedAt: nil, theme: .graphiteOrange)
        #expect(snapshot.lastSessionDate == nil && snapshot.lastRegion == nil)
        #expect(snapshot.daysSinceLast(at: date(25), calendar: calendar) == nil)
        #expect(snapshot.lastSummary(calendar: calendar) == nil)
        // 沒有紀錄時的建議：ME 下肢、3 個動作、不做跑步機
        #expect(snapshot.suggestedDayType == .meLower)
        #expect(snapshot.suggestedCount == 3)
        #expect(!snapshot.suggestsTreadmill)
        #expect(!snapshot.isInProgress && snapshot.startedAt == nil)
    }

    @Test func lastSessionAndTodaysSuggestion() {
        let history = PlanHistory([
            session(23, .upper, [.maxEffort, .pull, .cardio], dayType: .meUpper),
            session(20, .lower, [.maxEffort, .lowerAssist, .core], dayType: .meLower),
        ])
        var snapshot = WidgetSnapshot.make(history: history, activeStartedAt: nil, theme: .graphiteOrange)
        #expect(snapshot.lastSessionDate == date(23))
        #expect(snapshot.lastRegion == .upper && snapshot.lastDayType == .meUpper)
        #expect(snapshot.lastSummary(calendar: calendar) == "ME 上肢・10/23")
        // 和建立菜單的預設答案一致：下一個日型、動作數同上次（不計有氧）、上次有跑步機就建議跑步機
        #expect(snapshot.suggestedDayType == .deLower)
        #expect(snapshot.suggestedCount == 2)
        #expect(snapshot.suggestsTreadmill)
        #expect(snapshot.daysSinceLast(at: date(25, 8), calendar: calendar) == 2)
        #expect(WidgetSnapshot.daysText(2) == "2 天前")
        // 沒有日型的舊紀錄顯示部位
        snapshot.lastDayType = nil
        #expect(snapshot.lastSummary(calendar: calendar) == "上半身・10/23")
    }

    @Test func daysCountCalendarDays() {
        var snapshot = WidgetSnapshot.make(history: PlanHistory([]), activeStartedAt: nil, theme: .graphiteOrange)
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
                                           activeStartedAt: started, theme: .graphiteOrange)
        #expect(snapshot.isInProgress)
        #expect(snapshot.startedAt == started)
        // 進行中仍保留上次已完成的訓練
        #expect(snapshot.lastSessionDate == date(23))
    }

    @Test func themeAndPalette() {
        var snapshot = WidgetSnapshot.make(history: PlanHistory([]), activeStartedAt: nil, theme: .graphitePurple)
        #expect(snapshot.themeID == "graphitePurple")
        #expect(WidgetSnapshot.palette(for: snapshot) == AppTheme.graphitePurple.palette)

        // App 更新後還沒開過：舊快照的主題對應到新主題；跟隨系統外觀的舊快照沒有 themeID
        snapshot.themeID = "midnightBlue"
        #expect(WidgetSnapshot.palette(for: snapshot) == AppTheme.graphiteBlue.palette)
        snapshot.themeID = nil
        #expect(WidgetSnapshot.palette(for: snapshot) == AppTheme.graphiteOrange.palette)

        // 讀不到快照：石墨橙
        #expect(WidgetSnapshot.palette(for: nil) == AppTheme.graphiteOrange.palette)
    }

    @Test func statusAndLink() {
        var snapshot = WidgetSnapshot.make(history: PlanHistory([]), activeStartedAt: nil, theme: .graphiteOrange)
        #expect(snapshot.status(at: date(25), calendar: calendar) == .neverTrained)
        // 沒有訓練時點小工具回到「今天」；建立菜單用右上角的＋
        #expect(snapshot.link == .today)
        snapshot.lastSessionDate = date(23)
        #expect(snapshot.status(at: date(25), calendar: calendar) == .trained(days: 2))
        snapshot.isInProgress = true
        snapshot.startedAt = date(25, 18)
        #expect(snapshot.status(at: date(25, 18, 30), calendar: calendar) == .inProgress(startedAt: date(25, 18)))
        #expect(snapshot.link == .workout)
    }

    @Test func timelineHasSevenMidnights() {
        let now = date(25, 18, 7)
        let dates = WidgetSnapshot.timelineDates(from: now, calendar: calendar)
        #expect(dates.count == 8)
        #expect(dates.first == now)
        #expect(Array(dates.dropFirst()) == (26...31).map { date($0, 0) } + [calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!])
    }

    @Test func lockScreenTexts() {
        var snapshot = WidgetSnapshot.make(history: PlanHistory([session(23, .upper, [.push], dayType: .deUpper)]),
                                           activeStartedAt: nil, theme: .graphiteOrange)
        #expect(snapshot.inlineText(at: date(25), calendar: calendar) == "上次訓練 2 天前・今天 ME 下肢")
        #expect(snapshot.rectangularFirstLine(days: 2) == "上次：2 天前・DE 上肢")
        // 今天已經練過：建議是下一次的
        #expect(snapshot.inlineText(at: date(23, 20), calendar: calendar) == "今天練過・下次 ME 下肢")
        #expect(WidgetSnapshot.suggestionLabel(days: 0) == "下次")
        #expect(WidgetSnapshot.suggestionLabel(days: 2) == "今天")
        // 沒有日型時寫部位，部位也未指定時只寫天數
        snapshot.lastDayType = nil
        #expect(snapshot.rectangularFirstLine(days: 2) == "上次：2 天前・上半身")
        snapshot.lastRegion = .unspecified
        #expect(snapshot.rectangularFirstLine(days: 2) == "上次：2 天前")
        // 沒有紀錄或訓練中，單行另外處理
        snapshot.isInProgress = true
        snapshot.startedAt = date(25, 18)
        #expect(snapshot.inlineText(at: date(25, 19), calendar: calendar) == nil)
    }

    @Test func storeWritesOnlyWhenChanged() throws {
        let defaults = try #require(UserDefaults(suiteName: "WidgetSnapshotTests.\(UUID().uuidString)"))
        var snapshot = WidgetSnapshot.make(history: PlanHistory([]), activeStartedAt: nil, theme: .graphiteOrange)
        #expect(WidgetSnapshotStore.save(snapshot, to: defaults))
        #expect(!WidgetSnapshotStore.save(snapshot, to: defaults))
        #expect(WidgetSnapshotStore.load(from: defaults) == snapshot)
        snapshot.isInProgress = true
        #expect(WidgetSnapshotStore.save(snapshot, to: defaults))
        #expect(WidgetSnapshotStore.load(from: defaults)?.isInProgress == true)
    }

    /// CHANGE_08 §5：鎖定畫面的即時動態最高 160 pt；休息和非休息用同一組固定高度
    @Test func liveActivityFitsTheLockScreen() {
        #expect(LiveActivityLayout.lockScreenHeight <= 160)
        #expect(LiveActivityLayout.lockScreenHeight == 150)
        // 休息狀態的中段：「休息」和下一組兩行、倒數、進度條都要放得進固定高度
        #expect(LiveActivityLayout.countdownSize + 4 + 6 <= LiveActivityLayout.middleHeight)
        #expect(LiveActivityLayout.islandCountdownSize + 4 + 6 <= LiveActivityLayout.islandMiddleHeight)
    }
}
