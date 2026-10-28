import XCTest

/// CHANGE_11 §1：分頁列交給系統（tabBarMinimizeBehavior(.onScrollDown)）；「訓練中」橫條在系統的附屬列
@MainActor
final class TabBarMinimizeUITests: XCTestCase {
    /// 往下捲之後分頁列縮小（其他分頁的按鈕不見），附屬列的「訓練中」橫條還在、可以點；捲回頂端時恢復。
    /// 模擬器（iOS 26.5）實測：系統只在捲回頂端時把分頁列恢復，中途往上捲不會（有沒有附屬列都一樣），這是系統的行為
    func testWorkoutBarStaysWhenTabBarMinimizes() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "1", "-historySegment", "stats", "-demoWorkout", "YES"])
        let collapse = app.buttons["縮小"].firstMatch
        XCTAssertTrue(collapse.waitForExistence(timeout: 15))
        // 等全螢幕的訓練畫面出現完再縮小
        try await Task.sleep(for: .seconds(1.5))
        collapse.tap()
        let bar = app.buttons["workoutMiniBar"].firstMatch
        let barShown = await bar.waitForHittable(true, timeout: 10)
        if !barShown { attachScreenshot("workout_bar_missing") }
        XCTAssertTrue(barShown, "縮小之後要有訓練中橫條")
        let settings = app.buttons["設定"].firstMatch
        let expanded = await settings.waitForHittable(true)
        XCTAssertTrue(expanded, "一開始分頁列是展開的")
        attachScreenshot("V1_tabbar_expanded")
        // 往下捲：系統把分頁列縮小，只留目前的分頁
        var minimized = false
        try await Task.sleep(for: .seconds(1))
        for _ in 0..<2 where !minimized {
            app.swipeUp(velocity: .slow)
            minimized = await settings.waitForHittable(false, timeout: 3)
        }
        attachScreenshot("V1_tabbar_minimized")
        XCTAssertTrue(minimized, "往下捲之後分頁列應該縮小")
        XCTAssertTrue(bar.exists && bar.isHittable, "分頁列縮小時，訓練中橫條要照樣顯示")
        // 捲回頂端：分頁列恢復。先等慣性停下來
        try await Task.sleep(for: .seconds(1.5))
        var restored = false
        for _ in 0..<3 where !restored {
            app.swipeDown(velocity: .fast)
            restored = await settings.waitForHittable(true, timeout: 3)
        }
        if !restored { attachScreenshot("V1_tabbar_not_restored") }
        XCTAssertTrue(restored, "捲回頂端之後分頁列應該恢復")
        // 點橫條展開訓練
        bar.tap()
        XCTAssertTrue(collapse.waitForExistence(timeout: 5), "點訓練中橫條要展開訓練畫面")
        // 收掉示範訓練，不影響其他測試
        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }

    /// 沒有進行中的訓練時，附屬列不出現
    func testNoAccessoryWithoutWorkout() async throws {
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "1"])
        XCTAssertTrue(app.buttons["設定"].waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1))
        XCTAssertFalse(app.buttons["workoutMiniBar"].exists, "沒有訓練時不該有訓練中橫條")
    }
}
