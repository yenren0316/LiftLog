import XCTest

/// CHANGE_14 §4：訓練摘要是推入的頁面（不是 sheet）。歷程「紀錄」和動作詳情「歷史」都推入同一個頁面；
/// 系統的返回和左邊緣往右滑返回；⋯ 的「編輯」打開編輯的全螢幕畫面；刪除後回到上一頁
@MainActor
final class SummaryPageUITests: XCTestCase {
    /// 系統的返回按鈕：通常寫上一頁的標題，放不下時系統只留箭頭
    private func backButton(_ app: XCUIApplication, to previous: String) -> XCUIElement {
        let bar = app.navigationBars["訓練摘要"]
        return bar.buttons[previous].exists ? bar.buttons[previous] : bar.buttons.element(boundBy: 0)
    }

    /// 摘要頁：系統導覽列的「訓練摘要」，左上角是返回上一頁
    private func assertSummaryPage(_ app: XCUIApplication, backTo previous: String, _ name: String) {
        let bar = app.navigationBars["訓練摘要"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "要推入訓練摘要頁")
        XCTAssertTrue(backButton(app, to: previous).exists, "要有返回按鈕：\(bar.buttons.allElementsBoundByIndex.map(\.label))")
        XCTAssertTrue(app.buttons["更多"].exists, "右上角要有 ⋯")
        // 全高的頁面：導覽列在畫面最上面，不是半高的浮窗
        XCTAssertLessThan(bar.frame.minY, 120, "頁面是全高：導覽列在 \(bar.frame.minY)")
        attachScreenshot(name)
    }

    func testRecordPushesTheSummaryAndGoesBack() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "1", "-historySegment", "records"])
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '個動作'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "紀錄要有列")
        try await Task.sleep(for: .seconds(1))
        row.tap()
        assertSummaryPage(app, backTo: "歷程", "V6_summary_page_top")
        // 系統的返回按鈕
        backButton(app, to: "歷程").tap()
        XCTAssertTrue(app.navigationBars["歷程"].waitForExistence(timeout: 5), "返回要回到歷程的紀錄")
        XCTAssertFalse(app.navigationBars["訓練摘要"].exists)

        // 左邊緣往右滑返回
        try await Task.sleep(for: .seconds(1))
        row.tap()
        XCTAssertTrue(app.navigationBars["訓練摘要"].waitForExistence(timeout: 5))
        try await Task.sleep(for: .seconds(1))
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 2, dy: 0))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        XCTAssertTrue(app.navigationBars["歷程"].waitForExistence(timeout: 5), "從左邊緣往右滑要返回")

        // 捲到最底：內容完整（截圖）
        row.tap()
        XCTAssertTrue(app.navigationBars["訓練摘要"].waitForExistence(timeout: 5))
        try await Task.sleep(for: .seconds(1))
        for _ in 0..<3 { app.swipeUp(velocity: .slow) }
        try await Task.sleep(for: .seconds(1))
        attachScreenshot("V6_summary_page_bottom")
    }

    func testEditOpensTheEditorAndDeleteGoesBack() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoDeletable", "YES", "-startTab", "1", "-historySegment", "records"])
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '刪除測試'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "-demoDeletable 要加一筆「刪除測試」")
        try await Task.sleep(for: .seconds(1))
        row.tap()
        assertSummaryPage(app, backTo: "歷程", "summary_page_deletable")

        // ⋯ → 編輯：打開編輯的畫面，「完成」回到摘要頁
        app.buttons["更多"].tap()
        let edit = app.buttons["編輯"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()
        let editor = app.navigationBars["編輯訓練"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "「編輯」要打開編輯訓練")
        attachScreenshot("summary_page_editor")
        editor.buttons["完成"].tap()
        XCTAssertTrue(app.navigationBars["訓練摘要"].waitForExistence(timeout: 5), "完成後回到摘要頁")

        // ⋯ → 刪除：置中的 alert 確認，刪除後回到上一頁，這一列不見了
        try await Task.sleep(for: .seconds(1))
        app.buttons["更多"].tap()
        let delete = app.buttons["刪除"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        let alert = app.alerts["刪除這次訓練？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "刪除要先確認")
        XCTAssertTrue(alert.buttons["取消"].exists)
        alert.buttons["刪除"].tap()
        XCTAssertTrue(app.navigationBars["歷程"].waitForExistence(timeout: 5), "刪除後要回到上一頁")
        let gone = row.waitForNonExistence(timeout: 5)
        XCTAssertTrue(gone, "刪除的訓練不在紀錄裡")
        attachScreenshot("summary_page_deleted")
    }

    func testExerciseHistoryPushesTheSameSummaryPage() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "2", "-openExercise", "臥推", "-detailTab", "history"])
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '20'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "歷史分頁要有紀錄")
        try await Task.sleep(for: .seconds(1))
        row.tap()
        assertSummaryPage(app, backTo: "臥推", "summary_page_from_detail")
        backButton(app, to: "臥推").tap()
        XCTAssertTrue(app.navigationBars["臥推"].waitForExistence(timeout: 5), "返回要回到動作詳情")
    }
}
