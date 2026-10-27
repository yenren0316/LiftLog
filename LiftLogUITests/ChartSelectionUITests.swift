import XCTest

/// CHANGE_10 §0-1：有氧和體重的圖表也可以點一下選取（浮出標籤），上下滑照樣捲動
@MainActor
final class ChartSelectionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "YES", "-startTab", "1", "-historySegment", "stats", "-statsScrollTo", "weight"]
        app.launch()
        XCTAssertTrue(app.staticTexts["近 12 週・每週跑步機分鐘"].waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1.5))
    }

    func testTapOnCardioChartSelectsAWeek() async throws {
        let title = app.staticTexts["近 12 週・每週跑步機分鐘"].firstMatch.frame
        app.point(x: app.frame.midX - 40, y: title.maxY + 90).tap()
        try await Task.sleep(for: .seconds(0.5))
        attachScreenshot("cardio_peek")
        let value = app.descendants(matching: .any).matching(NSPredicate(format: "value CONTAINS '分鐘'")).firstMatch
        XCTAssertTrue(value.exists, "點有氧的長條沒有選到")
    }

    func testTapOnWeightChartSelectsADay() async throws {
        let picker = app.buttons["6 個月"].firstMatch
        XCTAssertTrue(picker.exists)
        app.point(x: app.frame.midX, y: picker.frame.maxY + 80).tap()
        try await Task.sleep(for: .seconds(0.5))
        attachScreenshot("weight_peek")
        let value = app.descendants(matching: .any).matching(NSPredicate(format: "value CONTAINS '・' AND value CONTAINS 'kg'")).firstMatch
        XCTAssertTrue(value.exists, "點體重的折線沒有選到")
    }
}
