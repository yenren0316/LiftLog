import Foundation
import Testing
@testable import LiftLog

/// CHANGE_07 C-3：編輯時間時，完成時間的平移與限制（T7）
struct SessionTimeEditTests {
    private let calendar = Calendar.current
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private var times: SessionTimeEdit.Times {
        SessionTimeEdit.Times(start: at(20, 9, 10), end: at(20, 10, 25),
                              completions: [at(20, 9, 20), at(20, 9, 50), nil, at(20, 10, 20)])
    }

    @Test func movingTheStartShiftsEverything() {
        // 開始時間往後 30 分：結束和所有完成時間一起平移
        let moved = SessionTimeEdit.moveStart(times, to: at(20, 9, 40))
        #expect(moved.end == at(20, 10, 55))
        #expect(moved.completions == [at(20, 9, 50), at(20, 10, 20), nil, at(20, 10, 50)])
        // 改日期（時間不變）：整次訓練搬到那天
        let newDay = SessionTimeEdit.combine(day: at(18, 0), time: times.start)
        let otherDay = SessionTimeEdit.moveStart(times, to: newDay)
        #expect(otherDay.start == at(18, 9, 10) && otherDay.end == at(18, 10, 25))
        #expect(otherDay.completions.first == at(18, 9, 20))
    }

    @Test func settingTheEndClampsCompletions() {
        // 只改結束時間：超出範圍的完成時間限制在開始到結束之間
        let shorter = try! #require(SessionTimeEdit.setEnd(times, to: at(20, 9, 45)))
        #expect(shorter.start == times.start && shorter.end == at(20, 9, 45))
        #expect(shorter.completions == [at(20, 9, 20), at(20, 9, 45), nil, at(20, 9, 45)])
        // 結束必須晚於開始
        #expect(SessionTimeEdit.setEnd(times, to: at(20, 9, 10)) == nil)
        #expect(SessionTimeEdit.setEnd(times, to: at(20, 8)) == nil)
    }

    @Test func combineKeepsTheTimeOfDay() {
        #expect(SessionTimeEdit.combine(day: at(1, 0), time: at(20, 18, 35)) == at(1, 18, 35))
    }

    /// 摘要頁的時間固定 24 小時制（地區是 12 小時制時也不能變成「06:30」）
    @Test @MainActor func summaryTimeTextUsesTwentyFourHours() {
        let evening = WorkoutSession(startedAt: at(25, 18, 30), endedAt: at(25, 19, 45))
        #expect(WorkoutSummaryPage.timeText(evening, calendar: calendar) == "18:30–19:45・75 分")
        let morning = WorkoutSession(startedAt: at(25, 7, 5), endedAt: at(25, 8, 0))
        #expect(WorkoutSummaryPage.timeText(morning, calendar: calendar) == "07:05–08:00・55 分")
        let untimed = WorkoutSession(startedAt: at(25, 12), endedAt: at(25, 12), hasTime: false)
        #expect(WorkoutSummaryPage.timeText(untimed, calendar: calendar) == "未記錄時間")
    }
}
