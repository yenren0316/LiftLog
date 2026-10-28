import XCTest

/// CHANGE_12 §1：經過時間和休息倒數改用系統的計時文字。格式和以前一樣（「24:30」「1:05:30」），
/// 「+15」「-15」「跳過」之後倒數立刻更新
@MainActor
final class TimerTextUITests: XCTestCase {
    func testElapsedOverAnHour() async throws {
        try await checkElapsed(3930, pattern: #"^1:0[56]:\d\d$"#, example: "1:05:30")
    }

    func testElapsedUnderAnHour() async throws {
        try await checkElapsed(1470, pattern: #"^2[45]:\d\d$"#, example: "24:30")
    }

    func testRestCountdownUpdatesRightAway() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoWorkout", "YES", "-demoRest", "90"])
        XCTAssertTrue(app.buttons["縮小"].waitForExistence(timeout: 15))
        allowNotificationsIfAsked()
        let countdown = app.staticTexts["restCountdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5), "要有休息倒數")
        attachScreenshot("rest_countdown")
        // +15：倒數立刻多 15 秒（扣掉點擊花的時間）
        let start = try seconds(in: countdown.label)
        app.buttons["+15"].tap()
        let plus = try seconds(in: countdown.label)
        XCTAssertTrue((start + 12...start + 15).contains(plus), "+15 之後應該是 \(start + 15) 秒左右，實際「\(countdown.label)」（之前 \(start) 秒）")
        // -15：立刻少 15 秒
        app.buttons["-15"].tap()
        let minus = try seconds(in: countdown.label)
        XCTAssertTrue((plus - 18...plus - 15).contains(minus), "-15 之後應該是 \(plus - 15) 秒左右，實際「\(countdown.label)」（之前 \(plus) 秒）")
        // 跳過：倒數立刻消失
        app.buttons["跳過"].tap()
        XCTAssertTrue(countdown.waitForNonExistence(timeout: 1), "跳過之後倒數應該立刻消失")
        try await discardDemoWorkout(app)
    }

    /// 訓練畫面的經過時間和附屬列的「訓練中」都要符合格式
    private func checkElapsed(_ elapsed: Int, pattern: String, example: String) async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoWorkout", "YES", "-demoWorkoutElapsed", "\(elapsed)"])
        let collapse = app.buttons["縮小"].firstMatch
        XCTAssertTrue(collapse.waitForExistence(timeout: 15))
        let text = app.staticTexts["elapsedTime"]
        XCTAssertTrue(text.waitForExistence(timeout: 5), "訓練畫面要有經過時間")
        XCTAssertNotNil(text.label.range(of: pattern, options: .regularExpression),
                        "訓練畫面的經過時間應該像「\(example)」，實際是「\(text.label)」")
        attachScreenshot("elapsed_\(example)")
        // 縮小：附屬列的「訓練中 1:05:30」
        try await Task.sleep(for: .seconds(1.5))
        collapse.tap()
        let bar = app.buttons["workoutMiniBar"].firstMatch
        let shown = await bar.waitForHittable(true, timeout: 10)
        XCTAssertTrue(shown, "縮小之後要有訓練中橫條")
        let barTime = bar.label.range(of: #"訓練中 [\d:]+"#, options: .regularExpression)
            .map { String(bar.label[$0].dropFirst(4)) } ?? ""
        XCTAssertNotNil(barTime.range(of: pattern, options: .regularExpression),
                        "附屬列應該是「訓練中 \(example)」這種格式，實際是「\(bar.label)」")
        try await discardDemoWorkout(app)
    }

    /// 「休息 1:27」→ 87
    private func seconds(in label: String) throws -> Int {
        let time = try XCTUnwrap(label.range(of: #"\d+:\d\d"#, options: .regularExpression).map { label[$0] },
                                 "倒數的文字應該像「休息 1:27」，實際是「\(label)」")
        let parts = time.split(separator: ":").compactMap { Int($0) }
        return parts[0] * 60 + parts[1]
    }

    private func discardDemoWorkout(_ app: XCUIApplication) async throws {
        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }
}
