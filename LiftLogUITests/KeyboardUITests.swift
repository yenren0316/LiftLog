import XCTest

/// CHANGE_10 §1：鍵盤上方不再有 CHANGE_08 的「完成」；點輸入框以外的地方、往下捲都能收起鍵盤
@MainActor
final class KeyboardUITests: XCTestCase {
    private var keyboardShown: Bool { XCUIApplication().keyboards.firstMatch.exists }

    private func waitForKeyboard(_ shown: Bool, timeout: TimeInterval = 3) async -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if keyboardShown == shown { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return keyboardShown == shown
    }

    /// 記錄體重（不能捲動的 sheet）：數字鍵盤上方沒有「完成」，點空白處收起
    func testWeightSheetDismissesOnTapOutside() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "1", "-historySegment", "stats",
                                         "-openWeightEntry", "YES", "-focusWeight", "YES"])
        let opened = app.navigationBars["記錄體重"].waitForExistence(timeout: 15)
        if !opened { attachScreenshot("weight_sheet_missing") }
        XCTAssertTrue(opened, "要打開記錄體重")
        let shown = await waitForKeyboard(true, timeout: 5)
        XCTAssertTrue(shown, "要自動打開數字鍵盤")
        try await Task.sleep(for: .seconds(0.8))
        attachScreenshot("weight_keyboard")
        XCTAssertFalse(app.toolbars.buttons["完成"].exists, "鍵盤上方不該有「完成」")
        XCTAssertFalse(app.buttons["完成"].exists, "畫面上不該有「完成」")
        // 點標題列（不是輸入框）；模擬器忙的時候第一下可能沒被收到，最多點兩次
        var hidden = false
        for _ in 0..<2 where !hidden {
            app.navigationBars["記錄體重"].staticTexts["記錄體重"].tap()
            hidden = await waitForKeyboard(false, timeout: 4)
        }
        XCTAssertTrue(hidden, "點輸入框以外的地方要收起鍵盤")
        // 點輸入框又會打開
        app.textFields.firstMatch.tap()
        let again = await waitForKeyboard(true, timeout: 5)
        XCTAssertTrue(again)
    }

    /// 訓練中填重量：點空白處、往下拖都能收起；訓練自己的鍵盤列（下一格）還在
    func testWorkoutFieldsDismiss() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoWorkout", "YES"])
        XCTAssertTrue(app.buttons["縮小"].waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1.5))
        // 組的重量欄（窄的那幾格；最上面的訓練名稱也是輸入框）
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        let field = app.textFields.allElementsBoundByIndex.first { $0.frame.width < 120 && $0.isHittable } ?? app.textFields.firstMatch
        let fields = app.textFields.allElementsBoundByIndex.prefix(4).map { "\($0.frame) \($0.isHittable)" }
        attachScreenshot("workout_before_tap")
        var shown = false
        for _ in 0..<2 where !shown {
            field.tap()
            shown = await waitForKeyboard(true, timeout: 5)
        }
        XCTAssertTrue(shown, "點重量欄要打開鍵盤：\(fields)")
        try await Task.sleep(for: .seconds(0.8))
        attachScreenshot("workout_keyboard")
        let toolbarButtons = app.toolbars.buttons.allElementsBoundByIndex.map(\.label) + app.keyboards.buttons.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(app.buttons["下一格"].exists || toolbarButtons.contains("下一格"), "訓練中的鍵盤列要保留：\(toolbarButtons)")
        // 點標題下面的日期（不是輸入框）
        var hiddenByTap = false
        for _ in 0..<2 where !hiddenByTap {
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '2026'")).firstMatch.tap()
            hiddenByTap = await waitForKeyboard(false, timeout: 4)
        }
        XCTAssertTrue(hiddenByTap, "點輸入框以外的地方要收起鍵盤")
        // 再打開，往下拖到鍵盤裡收起
        var shownAgain = false
        for _ in 0..<2 where !shownAgain {
            field.tap()
            shownAgain = await waitForKeyboard(true, timeout: 5)
        }
        XCTAssertTrue(shownAgain)
        let start = app.point(x: app.frame.midX, y: app.frame.height * 0.35)
        start.press(forDuration: 0.05, thenDragTo: app.point(x: app.frame.midX, y: app.frame.height * 0.95),
                    withVelocity: .default, thenHoldForDuration: 0.1)
        let hiddenByScroll = await waitForKeyboard(false)
        XCTAssertTrue(hiddenByScroll, "往下捲要收起鍵盤")
        // 收掉示範訓練
        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }
}
