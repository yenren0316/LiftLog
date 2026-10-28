import XCTest

/// CHANGE_12 §2：點附屬列的「訓練中」橫條打開訓練畫面，按左上角的收合回到附屬列。
/// 系統的放大轉場在附屬列裡找不到來源（只會從畫面中間放大），照規格維持原本的 fullScreenCover，
/// 這裡確認打開和收合的行為
@MainActor
final class WorkoutBarUITests: XCTestCase {
    func testBarOpensWorkoutAndCollapsesBack() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoWorkout", "YES"])
        let collapse = app.buttons["縮小"].firstMatch
        XCTAssertTrue(collapse.waitForExistence(timeout: 15))
        // 示範訓練一開始是全螢幕：等出現完再縮小
        try await Task.sleep(for: .seconds(1.5))
        collapse.tap()
        let bar = app.buttons["workoutMiniBar"].firstMatch
        let barShown = await bar.waitForHittable(true, timeout: 10)
        XCTAssertTrue(barShown, "縮小之後要有附屬列的橫條")

        for round in 1...2 {
            // 點橫條：打開訓練畫面
            bar.tap()
            let opened = await collapse.waitForHittable(true, timeout: 5)
            XCTAssertTrue(opened, "第 \(round) 次點附屬列的橫條要打開訓練畫面")
            XCTAssertTrue(app.staticTexts["elapsedTime"].exists, "打開的是訓練畫面")
            try await Task.sleep(for: .seconds(1))
            // 收合：回到附屬列
            collapse.tap()
            let collapsed = await bar.waitForHittable(true, timeout: 5)
            if !collapsed { attachScreenshot("not_collapsed_\(round)") }
            XCTAssertTrue(collapsed, "第 \(round) 次按收合之後要回到附屬列的橫條")
            XCTAssertTrue(collapse.waitForNonExistence(timeout: 3), "收合之後訓練畫面要關掉")
        }
        try await Task.sleep(for: .seconds(1))
        attachScreenshot("V2_collapsed_to_bar")

        // 收掉示範訓練，不影響其他測試
        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }
}
