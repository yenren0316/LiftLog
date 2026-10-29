import XCTest

/// CHANGE_10 §3、CHANGE_13 §2-2：整張「本週」卡打開「訓練狀態」；有紀錄的輪替列打開那次訓練的摘要浮窗
@MainActor
final class TrainingStatusUITests: XCTestCase {
    func testWeekCardOpensTrainingStatus() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "0"])
        let card = app.buttons["weekCard"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "本週卡要是一個按鈕")
        try await Task.sleep(for: .seconds(1))
        card.tap()
        let title = app.navigationBars["訓練狀態"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "點本週卡要打開訓練狀態")
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

    /// CHANGE_11 §7：浮窗高度等於內容的高度，打開就看得到全部（最後一列 DE 上肢在畫面裡）；往下拖可以關閉
    func testSheetFitsItsContent() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "0", "-trainingStatus", "YES"])
        let title = app.navigationBars["訓練狀態"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1.5))
        attachScreenshot("V2_training_status")
        let last = app.staticTexts["DE 上肢"].firstMatch
        XCTAssertTrue(last.exists && last.isHittable, "打開就要看得到最後一列")
        XCTAssertLessThan(last.frame.maxY, app.frame.maxY - 40, "最後一列要完整在畫面裡")
        // 不是全高：浮窗上面還看得到「今天」
        XCTAssertGreaterThan(title.frame.minY, 200, "內容不多時不該是全高：標題列在 \(title.frame.minY)")
        // 往下拖關閉
        let grab = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grab.press(forDuration: 0.05, thenDragTo: app.point(x: app.frame.midX, y: app.frame.maxY - 20),
                   withVelocity: .fast, thenHoldForDuration: 0)
        let closed = title.waitForNonExistence(timeout: 4)
        XCTAssertTrue(closed, "往下拖要能關閉")
    }

    /// 系統字級最大：內容超過螢幕時用全高，內容可以捲動到最後一列
    func testLargestTextUsesFullHeightAndScrolls() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "0", "-trainingStatus", "YES",
                                         "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let title = app.navigationBars["訓練狀態"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1.5))
        attachScreenshot("V2_training_status_largest_text")
        XCTAssertLessThan(title.frame.minY, 140, "內容超過螢幕時用全高：標題列在 \(title.frame.minY)")
        let last = app.staticTexts["DE 上肢"].firstMatch
        for _ in 0..<4 where !(last.exists && last.isHittable) { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(last.exists && last.isHittable, "捲動後要看得到最後一列")
        attachScreenshot("V2_training_status_largest_text_scrolled")
    }
}
