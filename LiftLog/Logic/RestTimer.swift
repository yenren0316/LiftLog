import Foundation
import Observation
import UserNotifications

/// 休息結束的本機通知
protocol RestNotifying {
    func schedule(at endDate: Date)
    func cancel()
}

/// 用 UNUserNotificationCenter 排程（App 在前景時系統不會顯示，改由震動提示）
struct RestNotifications: RestNotifying {
    private static let id = "rest-timer"

    func schedule(at endDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.id])
        let interval = endDate.timeIntervalSinceNow
        guard interval > 0.5 else { return }
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "休息結束"
            content.body = "開始下一組吧！"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: Self.id, content: content, trigger: trigger))
        }
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.id])
    }
}

/// 休息計時器。結束時間用時間戳記保存，App 到背景或重開後仍然準確。
/// App 畫面和即時動態的按鈕共用同一個（shared），所以兩邊的操作會互相反映。
@Observable
final class RestTimer {
    static let shared = RestTimer()

    private(set) var endDate: Date?
    private(set) var duration: TimeInterval = 0
    /// 每次倒數結束 +1，畫面用來觸發震動
    private(set) var finishedCount = 0
    /// 開始、調整、跳過或倒數結束時呼叫（即時動態用）
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notifications: RestNotifying
    private static let endKey = "restTimer.endDate"
    private static let durationKey = "restTimer.duration"

    init(defaults: UserDefaults = .standard, notifications: RestNotifying = RestNotifications()) {
        self.defaults = defaults
        self.notifications = notifications
        if let saved = defaults.object(forKey: Self.endKey) as? Date, saved > .now {
            endDate = saved
            duration = defaults.double(forKey: Self.durationKey)
            scheduleCompletion()
        } else {
            defaults.removeObject(forKey: Self.endKey)
        }
    }

    var isRunning: Bool { endDate != nil }

    /// 這次休息開始的時間（進度條用）
    var startDate: Date? { endDate?.addingTimeInterval(-duration) }

    func start(seconds: Int) {
        duration = TimeInterval(seconds)
        set(endDate: .now.addingTimeInterval(duration))
    }

    func adjust(by seconds: TimeInterval) {
        guard let endDate else { return }
        let newEnd = endDate.addingTimeInterval(seconds)
        if newEnd <= .now {
            skip()
        } else {
            duration = max(1, duration + seconds)
            set(endDate: newEnd)
        }
    }

    func skip() {
        set(endDate: nil)
    }

    // MARK: - 內部

    private func set(endDate: Date?) {
        self.endDate = endDate
        if let endDate {
            defaults.set(endDate, forKey: Self.endKey)
            defaults.set(duration, forKey: Self.durationKey)
        } else {
            defaults.removeObject(forKey: Self.endKey)
        }
        scheduleCompletion()
        if let endDate { notifications.schedule(at: endDate) } else { notifications.cancel() }
        onChange?()
    }

    /// 前景：時間到時震動（由畫面觀察 finishedCount）
    private func scheduleCompletion() {
        task?.cancel()
        guard let endDate else { return }
        task = Task { @MainActor [weak self] in
            let wait = endDate.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled, let self, self.endDate == endDate else { return }
            self.endDate = nil
            self.defaults.removeObject(forKey: Self.endKey)
            self.finishedCount += 1
            self.onChange?()
        }
    }
}
