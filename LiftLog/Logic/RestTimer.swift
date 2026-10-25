import Foundation
import Observation
import UserNotifications

/// 休息計時器。結束時間用時間戳記保存，App 到背景或重開後仍然準確。
@Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var duration: TimeInterval = 0
    /// 每次倒數結束 +1，畫面用來觸發震動
    private(set) var finishedCount = 0

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let defaults = UserDefaults.standard
    private static let endKey = "restTimer.endDate"
    private static let durationKey = "restTimer.duration"
    private static let notificationID = "rest-timer"

    init() {
        if let saved = defaults.object(forKey: Self.endKey) as? Date, saved > .now {
            endDate = saved
            duration = defaults.double(forKey: Self.durationKey)
            scheduleCompletion()
        } else {
            defaults.removeObject(forKey: Self.endKey)
        }
    }

    var isRunning: Bool { endDate != nil }

    func remaining(at date: Date) -> TimeInterval {
        max(0, (endDate ?? date).timeIntervalSince(date))
    }

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
        scheduleNotification()
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
        }
    }

    /// 背景：本機通知（App 在前景時系統不會顯示，改由震動提示）
    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        guard let endDate else { return }
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
            try? await center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
        }
    }
}
