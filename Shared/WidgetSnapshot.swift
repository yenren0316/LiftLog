import Foundation

/// 小工具用的快照（CHANGE_05 第 2 節）。App 算好後存進 App Group 的 UserDefaults；
/// 小工具只讀這份資料，不碰 SwiftData 資料庫。
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// 最後一次已完成的訓練；從來沒有紀錄時為 nil
    var lastSessionDate: Date?
    var lastRegion: Region?
    /// 今天的建議，和建立菜單的預設答案一致
    var suggestedRegion: Region
    var suggestedCount: Int
    var suggestsTreadmill: Bool
    /// 進行中的訓練
    var isInProgress: Bool
    var startedAt: Date?
    /// 目前的主題
    var themeID: String?

    /// 從上次訓練到 date 經過幾個日曆天（同一天為 0）；沒有紀錄時為 nil
    func daysSinceLast(at date: Date, calendar: Calendar = .current) -> Int? {
        guard let lastSessionDate else { return nil }
        let from = calendar.startOfDay(for: lastSessionDate), to = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    /// 「今天」「2 天前」
    static func daysText(_ days: Int) -> String {
        days == 0 ? "今天" : "\(days) 天前"
    }

    /// 「上半身・10/23」；部位未指定時只有日期
    func lastSummary(calendar: Calendar = .current) -> String? {
        guard let lastSessionDate else { return nil }
        let parts = calendar.dateComponents([.month, .day], from: lastSessionDate)
        let date = "\(parts.month ?? 0)/\(parts.day ?? 0)"
        guard let lastRegion, lastRegion != .unspecified else { return date }
        return "\(lastRegion.title)・\(date)"
    }

    /// 快照裡主題的配色；沒有快照時用石墨橙
    static func palette(for snapshot: WidgetSnapshot?) -> Palette {
        AppTheme(stored: snapshot?.themeID).palette
    }
}

/// 快照存在 App Group 的 UserDefaults
nonisolated enum WidgetSnapshotStore {
    static let appGroupID = "group.com.aaronhou.LiftLog"
    static let key = "widgetSnapshot.v1"

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static func load(from defaults: UserDefaults? = groupDefaults) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// 內容有變才寫入；回傳是否寫入
    @discardableResult
    static func save(_ snapshot: WidgetSnapshot, to defaults: UserDefaults? = groupDefaults) -> Bool {
        guard let defaults, load(from: defaults) != snapshot,
              let data = try? JSONEncoder().encode(snapshot) else { return false }
        defaults.set(data, forKey: key)
        return true
    }
}
