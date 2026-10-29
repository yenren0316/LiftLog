import XCTest

/// CHANGE_15 §4：完成訓練時有新紀錄，完成畫面最上方是「新紀錄」區塊（動作、新的估算 1RM、之前最好的）；
/// 歷程的訓練摘要頁在那個動作名稱旁有小獎盃。測試最後刪掉這次訓練，不影響其他測試
@MainActor
final class NewRecordUITests: XCTestCase {
    func testNewRecordOnTheFinishScreenAndTheSummaryPage() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoWorkout", "YES"])
        XCTAssertTrue(app.buttons["縮小"].firstMatch.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1.5))
        // 臥推第 1 組：200 kg × 3（估算 1RM 220 kg，高於以前所有的紀錄），打勾
        let weight = app.textFields["臥推-1-weight"], reps = app.textFields["臥推-1-reps"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("200")
        reps.tap()
        reps.typeText("3")
        app.buttons["臥推-1-check"].tap()
        allowNotificationsIfAsked()
        try await Task.sleep(for: .seconds(0.5))
        // 完成：其他沒打勾的組刪掉
        app.navigationBars.buttons["完成"].firstMatch.tap()
        let deleteIncomplete = app.alerts.buttons["刪除未完成的組"]
        XCTAssertTrue(deleteIncomplete.waitForExistence(timeout: 5))
        deleteIncomplete.tap()
        let records = app.descendants(matching: .any)["newRecords"].firstMatch
        XCTAssertTrue(records.waitForExistence(timeout: 5), "完成畫面要有「新紀錄」區塊")
        XCTAssertTrue(records.label.contains("新紀錄") && records.label.contains("臥推") && records.label.contains("估算 1RM 220 kg")
                      && records.label.contains("之前"), records.label)
        // 在最上方（「訓練完成」上面）
        XCTAssertLessThan(records.frame.maxY, app.staticTexts["訓練完成"].frame.minY, "新紀錄在最上方")
        try await Task.sleep(for: .seconds(1.5))
        attachScreenshot("V7_finish_new_record")
        app.buttons["完成"].firstMatch.tap()
        XCTAssertTrue(records.waitForNonExistence(timeout: 5))

        // 歷程的摘要頁：臥推旁邊有小獎盃
        app.tabBars.buttons["歷程"].tap()
        app.segmentedControls.buttons["紀錄"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '上肢訓練'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["訓練摘要"].waitForExistence(timeout: 5))
        let trophy = app.descendants(matching: .any)["newRecordTrophy"].firstMatch
        XCTAssertTrue(trophy.waitForExistence(timeout: 5), "摘要頁的臥推旁邊有獎盃")
        try await Task.sleep(for: .seconds(1))
        attachScreenshot("V7_summary_trophy")

        // 刪掉這次訓練
        app.navigationBars["訓練摘要"].buttons["更多"].tap()
        let delete = app.buttons["刪除"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        let confirm = app.alerts.buttons["刪除"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.navigationBars["歷程"].waitForExistence(timeout: 5))
    }
}
