import Foundation
import Testing
@testable import LiftLog

@MainActor
struct RestTimerTests {
    /// 不排真的通知（模擬器會跳出通知權限的對話框），也不寫進 App 的 UserDefaults
    final class SilentNotifications: RestNotifying {
        func schedule(at endDate: Date) {}
        func cancel() {}
    }

    private let defaults = UserDefaults(suiteName: "RestTimerTests.\(UUID().uuidString)")!

    private func makeTimer() -> RestTimer {
        RestTimer(defaults: defaults, notifications: SilentNotifications())
    }

    /// 畫面的倒數是系統的計時文字（CHANGE_12 §1），顯示的就是結束時間減掉現在
    private func remaining(_ timer: RestTimer, at date: Date) -> TimeInterval {
        max(0, (timer.endDate ?? date).timeIntervalSince(date))
    }

    @Test func remainingComesFromEndTimestamp() {
        let timer = makeTimer()
        timer.start(seconds: 90)
        defer { timer.skip() }
        let now = Date.now
        #expect(abs(remaining(timer, at: now) - 90) < 1)
        // 不靠累加計數：直接用時間戳推算 60 秒後的剩餘時間
        #expect(abs(remaining(timer, at: now.addingTimeInterval(60)) - 30) < 1)
        #expect(remaining(timer, at: now.addingTimeInterval(120)) == 0)
    }

    @Test func adjustAndSkip() {
        let timer = makeTimer()
        timer.start(seconds: 90)
        timer.adjust(by: 15)
        #expect(abs(remaining(timer, at: .now) - 105) < 1)
        #expect(timer.duration == 105)
        timer.adjust(by: -15)
        #expect(abs(remaining(timer, at: .now) - 90) < 1)
        timer.adjust(by: -200)   // 減到負數就等於跳過
        #expect(!timer.isRunning)
    }

    @Test func survivesRelaunchThroughStoredTimestamp() {
        let first = makeTimer()
        first.start(seconds: 120)
        let restored = makeTimer()   // 模擬重開 App（同一份 UserDefaults）
        defer { restored.skip(); first.skip() }
        #expect(restored.isRunning)
        #expect(abs(remaining(restored, at: .now) - 120) < 1)
    }
}
