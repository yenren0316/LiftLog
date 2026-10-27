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
        // 等 -statsScrollTo 捲完
        try await Task.sleep(for: .seconds(2))
    }

    /// 在圖表裡點一下，等選取的文字出現（圖表的 accessibilityValue）
    private func tapAndRead(_ identifier: String, at offset: CGVector) async -> String {
        let chart = app.descendants(matching: .any)[identifier].firstMatch
        guard chart.waitForExistence(timeout: 5) else { return "（找不到 \(identifier)）" }
        // 頁面還在捲動時，第一下只會停住捲動；最多點兩次
        for _ in 0..<2 {
            chart.coordinate(withNormalizedOffset: offset).tap()
            for _ in 0..<8 {
                if let value = chart.value as? String, !value.isEmpty { return value }
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
        return chart.value as? String ?? ""
    }

    func testTapOnCardioChartSelectsAWeek() async throws {
        let value = await tapAndRead("cardioChart", at: CGVector(dx: 0.3, dy: 0.7))
        attachScreenshot("cardio_peek")
        XCTAssertTrue(value.contains("分鐘") && value.contains("–"), "點有氧的長條沒有選到：「\(value)」")
    }

    func testTapOnWeightChartSelectsADay() async throws {
        let value = await tapAndRead("weightChart", at: CGVector(dx: 0.5, dy: 0.6))
        attachScreenshot("weight_peek")
        XCTAssertTrue(value.contains("・") && value.contains("kg"), "點體重的折線沒有選到：「\(value)」")
    }
}
