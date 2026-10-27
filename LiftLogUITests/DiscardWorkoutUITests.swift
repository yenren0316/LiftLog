import XCTest

/// CHANGE_10 §0-3：訓練畫面最底部的「捨棄訓練」和置中的確認對話框；「取消」不改任何東西
@MainActor
final class DiscardWorkoutUITests: XCTestCase {
    func testDiscardButtonAtTheBottomAsksFirst() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "YES", "-demoWorkout", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["縮小"].waitForExistence(timeout: 15))
        // 右上角沒有 ••• 選單
        XCTAssertFalse(app.navigationBars.buttons["More"].exists)
        let discard = app.buttons["捨棄訓練"].firstMatch
        for _ in 0..<8 where !discard.isHittable { app.swipeUp() }
        XCTAssertTrue(discard.isHittable, "最底部要有「捨棄訓練」")
        attachScreenshot("discard_button")
        discard.tap()
        let alert = app.alerts["捨棄這次訓練？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts["這次訓練的所有組都會刪除，無法復原。"].exists)
        attachScreenshot("discard_alert")
        // 取消：還在訓練中
        alert.buttons["取消"].tap()
        try await Task.sleep(for: .seconds(0.8))
        XCTAssertTrue(app.buttons["縮小"].exists, "取消之後應該還在訓練畫面")
        // 確認：回到分頁，沒有進行中的訓練
        discard.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["捨棄訓練"].tap()
        try await Task.sleep(for: .seconds(1.5))
        XCTAssertFalse(app.buttons["縮小"].exists, "捨棄之後應該離開訓練畫面")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS '訓練中'")).firstMatch.exists)
    }
}
