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

/// CHANGE_11 §5：動作詳情的折線圖和其他圖表同一套行為：點一下浮出數字、2 秒後消失；沒有「打開這次訓練」
@MainActor
final class DetailChartUITests: XCTestCase {
    func testTapShowsTheValueForTwoSeconds() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "2", "-openExercise", "臥推"])
        let chart = app.descendants(matching: .any)["trendChart"].firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 15), "動作詳情要有折線圖")
        try await Task.sleep(for: .seconds(1.5))
        // 折線圖在個人紀錄下面：捲到它整個在分頁列上方
        for _ in 0..<4 where chart.frame.maxY > app.frame.maxY - 140 {
            app.swipeUp(velocity: .slow)
            try await Task.sleep(for: .seconds(0.8))
        }
        var value = ""
        for _ in 0..<2 where value.isEmpty {
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).tap()
            try await Task.sleep(for: .milliseconds(400))
            value = chart.value as? String ?? ""
        }
        attachScreenshot("V5_detail_chart_peek")
        XCTAssertTrue(value.contains("・") && value.contains("kg"), "點一下要浮出那一點的數字：「\(value)」")
        XCTAssertFalse(app.buttons["打開這次訓練"].exists, "不該再有「打開這次訓練」")
        // 2 秒後消失，選取不再一直留著
        try await Task.sleep(for: .seconds(2.5))
        XCTAssertEqual(chart.value as? String ?? "", "", "2 秒後數字要消失")
    }
}
