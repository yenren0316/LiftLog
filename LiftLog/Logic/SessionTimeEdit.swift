import Foundation
import SwiftData

/// 編輯訓練的日期和時間（CHANGE_07 C-3）：
/// - 改日期或開始時間：結束時間和所有組的完成時間一起平移相同的時間差
/// - 只改結束時間：結束必須晚於開始；超出範圍的完成時間限制在開始到結束之間
nonisolated enum SessionTimeEdit {
    struct Times: Equatable {
        var start: Date
        var end: Date?
        var completions: [Date?]
    }

    static func moveStart(_ times: Times, to newStart: Date) -> Times {
        let delta = newStart.timeIntervalSince(times.start)
        return Times(start: newStart, end: times.end?.addingTimeInterval(delta),
                     completions: times.completions.map { $0?.addingTimeInterval(delta) })
    }

    /// 結束時間沒有晚於開始時回傳 nil（不接受）
    static func setEnd(_ times: Times, to newEnd: Date) -> Times? {
        guard newEnd > times.start else { return nil }
        return Times(start: times.start, end: newEnd,
                     completions: times.completions.map { $0.map { min(max($0, times.start), newEnd) } })
    }

    /// day 那天、time 的時和分
    static func combine(day: Date, time: Date, calendar: Calendar = .current) -> Date {
        let t = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: day) ?? day
    }
}

extension WorkoutSession {
    /// 這次訓練的時間和每一組的完成時間（依動作、組的順序）
    var editableTimes: SessionTimeEdit.Times {
        SessionTimeEdit.Times(start: startedAt, end: endedAt,
                              completions: orderedItems.flatMap { $0.orderedSets.map(\.completedAt) })
    }

    func apply(_ times: SessionTimeEdit.Times) {
        startedAt = times.start
        endedAt = times.end
        for (set, date) in zip(orderedItems.flatMap(\.orderedSets), times.completions) {
            set.completedAt = date
        }
    }

    /// 沒有時間資料的舊紀錄「設定時間」：從原本的時間開始，預設一小時
    func setTimeFromMissing() {
        hasTime = true
        let start = startedAt
        if let times = SessionTimeEdit.setEnd(editableTimes, to: start.addingTimeInterval(3600)) {
            apply(times)
        }
    }
}
