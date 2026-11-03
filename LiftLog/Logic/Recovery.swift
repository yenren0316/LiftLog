import Foundation

/// 48 小時規則（CHANGE_18 §2）：同一個動作最近一次完成組離現在不到 48 小時，建立菜單不建議它。
/// - 看的是同一個動作：不分角色、不分日型，自由選動作的訓練也算（「臥推（速度）」和「臥推」是同一個動作）。
/// - 「最近一次完成組的時間」是 PlanExercise.lastDate（PlanHistory.lastCompletedDates 填的），和「最久沒做」的排序同一個來源。
/// - 主項：輪到的在 48 小時內練過就往下找（Rotation.suggestion）；其他格子：48 小時內練過的排到最後（deferringRecent）。
/// 全 App 只有 isRecent 這一個判斷
nonisolated enum Recovery {
    static let hours = 48
    static var interval: TimeInterval { TimeInterval(hours) * 3600 }

    /// 現在減去最近一次完成組的時間小於 48 小時（實際時間，不是日曆日）；沒練過的不算
    static func isRecent(_ lastDate: Date?, now: Date) -> Bool {
        guard let lastDate else { return false }
        return now.timeIntervalSince(lastDate) < interval
    }

    /// 48 小時內練過的排到最後，兩邊各自維持原本的順序；全部都在 48 小時內時就是原本的順序
    static func deferringRecent(_ list: [PlanExercise], now: Date) -> [PlanExercise] {
        list.filter { !isRecent($0.lastDate, now: now) } + list.filter { isRecent($0.lastDate, now: now) }
    }

    /// 建議原因裡跳過的動作什麼時候練過：「今天」「昨天」，前天以前（還在 48 小時內）寫「47 小時前」
    static func whenText(_ lastDate: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = RelativeDay.days(since: lastDate, now: now, calendar: calendar) ?? 0
        if days <= 1 { return RelativeDay.text(days) }
        return "\(max(Int(now.timeIntervalSince(lastDate) / 3600), 0)) 小時前"
    }

    /// 最早一個「滿 48 小時」的時間（之後的建議可能會變）：統計快照到這個時間要重算；沒有為 nil
    static func nextBoundary(_ lastDates: some Sequence<Date>, now: Date) -> Date? {
        lastDates.map { $0.addingTimeInterval(interval) }.filter { $0 > now }.min()
    }
}
