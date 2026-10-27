import XCTest

/// CHANGE_10 §2、§3：整張日曆卡打開「訓練狀態」；有紀錄的輪替列打開那次訓練的摘要浮窗
@MainActor
final class TrainingStatusUITests: XCTestCase {
    func testCalendarCardOpensTrainingStatus() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "0"])
        let card = app.buttons["訓練日曆"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "日曆卡要是一個按鈕")
        try await Task.sleep(for: .seconds(1))
        card.tap()
        let title = app.navigationBars["訓練狀態"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "點日曆卡要打開訓練狀態")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '本週・'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '上週同期：'")).firstMatch.exists)
        attachScreenshot("training_status")
        // 有紀錄的列（有「天前」）可以點：關掉這個浮窗，打開摘要
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '天前'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3), "示範資料裡至少一個日型有紀錄")
        row.tap()
        let summaryMenu = app.buttons["更多"].firstMatch
        XCTAssertTrue(summaryMenu.waitForExistence(timeout: 5), "要打開那次訓練的摘要浮窗")
        XCTAssertFalse(title.exists, "訓練狀態要先關掉")
    }
}
