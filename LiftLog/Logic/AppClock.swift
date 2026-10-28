import Foundation

/// App 的「現在」（CHANGE_11 §9）。統計快照和依日期計算的數字都從這裡取時間；
/// DEBUG 版可以用 -fakeNow 固定，用來在模擬器上重現某個時間點的統計
nonisolated enum AppClock {
    static var now: Date {
        #if DEBUG
        if let fake = fakeNow { return fake }
        #endif
        return .now
    }

    #if DEBUG
    // 開發用：-fakeNow 2026-01-05T00:05:00+08:00 固定 App 的「現在」（ISO 8601，沒有時區時用裝置的時區）
    static let fakeNow: Date? = UserDefaults.standard.string(forKey: "fakeNow").flatMap { parse($0) }
    #endif

    /// ISO 8601：有時區（「Z」「+08:00」）照寫的；沒有時區時用 timeZone
    static func parse(_ text: String, timeZone: TimeZone = .current) -> Date? {
        if let date = try? Date(text, strategy: .iso8601) { return date }
        let local = Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day().dateTimeSeparator(.standard).time(includingFractionalSeconds: false)
        return try? Date(text, strategy: local)
    }
}

/// 統計快照什麼時候要重算（CHANGE_11 §2）。快照裡依日期算的數字（本週、上週同期、N 天前、近 30 天、最久沒練、
/// 「下一次」卡、訓練頻率）除了存檔之外，日期改變時也要重算
nonisolated enum StatsRefresh {
    enum Trigger: Sendable {
        /// App 回到前景：日期和上次計算時不同才重算
        case foreground
        /// App 開著時跨過午夜（NSCalendarDayChanged）
        case dayChanged
        /// 時區或系統時間改變（significantTimeChange、NSSystemTimeZoneDidChange、NSSystemClockDidChange）
        case timeChanged
    }

    /// computedAt：上次計算的時間（快照的「現在」）；還沒算過一律重算
    static func needsRecompute(_ trigger: Trigger, computedAt: Date?, now: Date, calendar: Calendar) -> Bool {
        guard let computedAt else { return true }
        switch trigger {
        case .foreground: return !calendar.isDate(computedAt, inSameDayAs: now)
        case .dayChanged, .timeChanged: return true
        }
    }
}
