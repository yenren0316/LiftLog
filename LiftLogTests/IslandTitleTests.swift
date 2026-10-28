import Foundation
import Testing
@testable import LiftLog

/// CHANGE_11 §6：動態島展開時左上角是日型簡稱，沒有日型時「訓練」；鎖定畫面照舊是訓練名稱
struct IslandTitleTests {
    private typealias State = WorkoutActivityAttributes.ContentState

    private func state(dayTypeTitle: String?) -> State {
        State(title: "上肢速度與爆發・臥推", dayTypeTitle: dayTypeTitle, startedAt: .now, setNumber: 1, setCount: 3,
              canComplete: true, completedSets: 0, totalSets: 3)
    }

    @Test func shortNameOfTheDayType() {
        #expect(State.islandTitle(dayType: .deUpper) == "DE 上肢")
        #expect(State.islandTitle(dayType: .meLower) == "ME 下肢")
        #expect(state(dayTypeTitle: "DE 上肢").islandTitle == "DE 上肢")
        // 鎖定畫面的名稱不變
        #expect(state(dayTypeTitle: "DE 上肢").title == "上肢速度與爆發・臥推")
    }

    @Test func workoutWithoutDayTypeShowsTraining() {
        #expect(State.islandTitle(dayType: nil) == "訓練")
        #expect(state(dayTypeTitle: nil).islandTitle == "訓練")
    }

    /// 舊版 App 建立的即時動態沒有 dayTypeTitle，照樣解碼
    @Test func oldStateDecodes() throws {
        let old = #"{"title":"下肢訓練","startedAt":0,"setNumber":1,"setCount":3,"canComplete":true,"completedSets":0,"totalSets":3}"#
        let decoded = try JSONDecoder().decode(State.self, from: Data(old.utf8))
        #expect(decoded.dayTypeTitle == nil && decoded.islandTitle == "訓練" && decoded.title == "下肢訓練")
    }
}
