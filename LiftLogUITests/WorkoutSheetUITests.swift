import XCTest

/// CHANGE_15 §3：訓練畫面是系統的 sheet（只有全高）。往下拖關閉＝縮小到附屬列的「訓練中」橫條，訓練繼續；
/// 完成訓練後的完成畫面不能往下拖關閉，要按「完成」
@MainActor
final class WorkoutSheetUITests: XCTestCase {
    func testDraggingTheWorkoutDownCollapsesItToTheBar() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoWorkout", "YES", "-demoWorkoutElapsed", "65"])
        let collapse = app.buttons["縮小"].firstMatch
        XCTAssertTrue(collapse.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1.5))
        let elapsed = app.staticTexts["elapsedTime"].firstMatch
        let before = elapsed.label
        // 拖到一半停 2 秒再放回去（V6 的錄影取這一段），放開後訓練畫面還在
        let top = app.point(x: 201, y: 120)
        top.press(forDuration: 0.3, thenDragTo: app.point(x: 201, y: 480), withVelocity: .slow, thenHoldForDuration: 2)
        try await Task.sleep(for: .seconds(1.5))
        attachScreenshot("drag_released_halfway")
        // 從導覽列往下拖到底：縮小到附屬列，和按「縮小」一樣
        var collapsed = false
        let bar = app.buttons["workoutMiniBar"].firstMatch
        for _ in 0..<2 where !collapsed {
            app.point(x: 201, y: 120).press(forDuration: 0.1, thenDragTo: app.point(x: 201, y: 860), withVelocity: .fast,
                                            thenHoldForDuration: 0)
            collapsed = await bar.waitForHittable(true, timeout: 5)
        }
        attachScreenshot("dragged_down_to_bar")
        XCTAssertTrue(collapsed, "往下拖要縮小到附屬列的橫條")
        XCTAssertTrue(collapse.waitForNonExistence(timeout: 3), "訓練畫面要關掉")
        let next = app.buttons["nextCard"].firstMatch
        XCTAssertTrue(next.label.contains("進行中"), "訓練繼續進行：\(next.label)")
        // 再打開：還是同一次訓練，經過時間繼續走
        try await Task.sleep(for: .seconds(2))
        bar.tap()
        let opened = await collapse.waitForHittable(true, timeout: 5)
        XCTAssertTrue(opened, "點橫條再打開訓練畫面")
        XCTAssertNotEqual(elapsed.label, before, "經過時間繼續走（\(before) → \(elapsed.label)）")

        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }

    func testTheFinishScreenCannotBeDraggedAway() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-previewFinishSummary", "YES"])
        let title = app.staticTexts["訓練完成"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1.5))
        for _ in 0..<2 {
            app.point(x: 201, y: 120).press(forDuration: 0.1, thenDragTo: app.point(x: 201, y: 860), withVelocity: .fast,
                                            thenHoldForDuration: 0)
            try await Task.sleep(for: .seconds(1.5))
        }
        attachScreenshot("finish_after_drag")
        XCTAssertTrue(title.exists && title.isHittable, "完成畫面往下拖不會關閉")
        // 按「完成」才關閉
        app.buttons["完成"].firstMatch.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "按「完成」關閉")
    }
}
