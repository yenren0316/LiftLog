import Foundation

/// 小工具「＋」按鈕的 intent 要在 App 的程序裡執行才能導向建立菜單。萬一系統是在小工具的程序執行，
/// 那邊的 perform 先把連結存進 App Group，App 回到前景時接手（CHANGE_07 D-3）
nonisolated enum PendingDeepLink {
    static let key = "pendingDeepLink"

    static func store(_ link: DeepLink, in defaults: UserDefaults? = WidgetSnapshotStore.groupDefaults) {
        defaults?.set(link.rawValue, forKey: key)
    }

    /// 取出並清掉
    static func consume(from defaults: UserDefaults? = WidgetSnapshotStore.groupDefaults) -> DeepLink? {
        guard let raw = defaults?.string(forKey: key) else { return nil }
        defaults?.removeObject(forKey: key)
        return DeepLink(rawValue: raw)
    }
}
