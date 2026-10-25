import Foundation
import Testing
@testable import LiftLog

@MainActor
struct RestTimerTests {
    @Test func remainingComesFromEndTimestamp() {
        let timer = RestTimer()
        timer.start(seconds: 90)
        defer { timer.skip() }
        let now = Date.now
        #expect(abs(timer.remaining(at: now) - 90) < 1)
        // 不靠累加計數：直接用時間戳推算 60 秒後的剩餘時間
        #expect(abs(timer.remaining(at: now.addingTimeInterval(60)) - 30) < 1)
        #expect(timer.remaining(at: now.addingTimeInterval(120)) == 0)
    }

    @Test func adjustAndSkip() {
        let timer = RestTimer()
        timer.start(seconds: 90)
        timer.adjust(by: 15)
        #expect(abs(timer.remaining(at: .now) - 105) < 1)
        #expect(timer.duration == 105)
        timer.adjust(by: -15)
        #expect(abs(timer.remaining(at: .now) - 90) < 1)
        timer.adjust(by: -200)   // 減到負數就等於跳過
        #expect(!timer.isRunning)
    }

    @Test func survivesRelaunchThroughStoredTimestamp() {
        let first = RestTimer()
        first.start(seconds: 120)
        let restored = RestTimer()   // 模擬重開 App
        defer { restored.skip(); first.skip() }
        #expect(restored.isRunning)
        #expect(abs(restored.remaining(at: .now) - 120) < 1)
    }
}
