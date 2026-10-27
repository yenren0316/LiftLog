import XCTest

/// CHANGE_10 §0-2：四個分頁底下可以捲動的畫面，往下捲收起分頁列、往上捲出現
@MainActor
final class TabBarHidingUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch(_ arguments: [String]) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "YES", "-tabBarLog", "YES"] + arguments
        app.launch()
    }

    /// 分頁列上「今天」那顆按鈕：分頁列收起時不存在或點不到
    private var tabButton: XCUIElement { app.buttons["今天"].firstMatch }

    /// 在畫面中間往上滑一段（手指往上，內容往下捲），再往下滑一段
    private func assertHidesAndShows(_ screen: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        XCTAssertTrue(tabButton.waitForExistence(timeout: 10), "\(screen)：一開始分頁列要顯示", file: file, line: line)
        let middle = app.point(x: app.frame.midX, y: app.frame.midY + 60)
        middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: -160)), withVelocity: .slow, thenHoldForDuration: 0.3)
        let hidden = await tabButton.waitForHittable(false)
        if !hidden { attachScreenshot("\(screen)_not_hidden") }
        XCTAssertTrue(hidden, "\(screen)：往下捲之後分頁列應該收起", file: file, line: line)
        try await Task.sleep(for: .seconds(1))
        middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: 120)), withVelocity: .slow, thenHoldForDuration: 0.3)
        let shown = await tabButton.waitForHittable(true)
        if !shown { attachScreenshot("\(screen)_not_shown") }
        XCTAssertTrue(shown, "\(screen)：往上捲之後分頁列應該出現", file: file, line: line)
    }

    func testLibraryRoot() async throws {
        launch(["-startTab", "2"])
        XCTAssertTrue(app.staticTexts["下肢推（膝主導）"].waitForExistence(timeout: 15))
        try await assertHidesAndShows("動作庫第 1 層")
    }

    func testHistoryRecords() async throws {
        launch(["-startTab", "1", "-historySegment", "records"])
        XCTAssertTrue(app.buttons["紀錄"].waitForExistence(timeout: 15))
        try await assertHidesAndShows("歷程・紀錄")
    }

    func testHistoryStats() async throws {
        launch(["-startTab", "1", "-historySegment", "stats"])
        XCTAssertTrue(app.staticTexts["主項進步"].waitForExistence(timeout: 15))
        try await assertHidesAndShows("歷程・統計")
    }

    func testLibraryCategory() async throws {
        launch(["-startTab", "2", "-libraryCategory", "core"])
        XCTAssertTrue(app.navigationBars["核心"].waitForExistence(timeout: 15))
        try await assertHidesAndShows("動作庫・分類清單")
    }

    func testLibraryArchived() async throws {
        launch(["-startTab", "2", "-openArchived", "YES"])
        XCTAssertTrue(app.navigationBars["已封存"].waitForExistence(timeout: 15))
        try await assertHidesAndShows("動作庫・已封存")
    }

    func testTodayCategory() async throws {
        launch(["-startTab", "0", "-todayCategory", "core"])
        XCTAssertTrue(app.navigationBars["核心"].waitForExistence(timeout: 15))
        try await assertHidesAndShows("今天・分類待練清單")
    }

    /// 分頁列收起時，「訓練中」橫條照樣顯示（可以點）
    func testWorkoutBarStaysWhenTabBarHides() async throws {
        launch(["-startTab", "1", "-historySegment", "stats", "-demoWorkout", "YES"])
        let collapse = app.buttons["縮小"].firstMatch
        XCTAssertTrue(collapse.waitForExistence(timeout: 15))
        // 等全螢幕的訓練畫面出現完再縮小
        try await Task.sleep(for: .seconds(1.5))
        collapse.tap()
        let bar = app.buttons.matching(NSPredicate(format: "label CONTAINS '訓練中'")).firstMatch
        let barShown = await bar.waitForHittable(true, timeout: 10)
        if !barShown { attachScreenshot("workout_bar_missing") }
        XCTAssertTrue(barShown, "縮小之後要有訓練中橫條")
        try await assertHidesAndShows("歷程・統計（訓練中）")
        // 再收起一次，確認橫條還在
        let middle = app.point(x: app.frame.midX, y: app.frame.midY + 60)
        middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: -160)), withVelocity: .slow, thenHoldForDuration: 0.3)
        let hiddenAgain = await tabButton.waitForHittable(false)
        XCTAssertTrue(hiddenAgain, "分頁列應該收起")
        attachScreenshot("workout_bar_tab_hidden")
        XCTAssertTrue(bar.isHittable, "分頁列收起時，訓練中橫條要照樣顯示")
        // 收掉示範訓練，不影響其他測試
        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }
}
