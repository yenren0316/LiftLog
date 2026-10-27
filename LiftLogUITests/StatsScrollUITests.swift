import XCTest

/// CHANGE_10 §0-1：歷程的統計頁用手指捲到最底部後，從圖表或下面的卡片開始往上捲（手指往下拖）要捲得動
@MainActor
final class StatsScrollUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "YES", "-startTab", "1", "-historySegment", "stats"]
        app.launch()
        XCTAssertTrue(app.staticTexts["主項進步"].waitForExistence(timeout: 15))
        // 用手指捲到最底部
        for _ in 0..<4 { app.swipeUp(velocity: .fast) }
        try await Task.sleep(for: .seconds(2))
    }

    /// 從 anchor 的位置（加上 dy）開始，手指往下拖 distance；回傳「訓練頻率」標題往下移了多少，以及診斷用的說明
    private func dragDown(from anchor: XCUIElement, dy: CGFloat, distance: CGFloat = 200) async throws -> (CGFloat, String) {
        let title = app.staticTexts["訓練頻率"].firstMatch
        let before = title.frame.minY
        let y = anchor.frame.midY + dy
        let tab = app.buttons["歷程"].firstMatch
        let info = "start y=\(Int(y)) title y=\(Int(before)) tab=\(tab.exists ? "\(tab.isHittable) \(tab.frame)" : "none")"
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.midX, dy: y))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                    withVelocity: .default, thenHoldForDuration: 0.2)
        try await Task.sleep(for: .seconds(1.5))
        return (title.frame.minY - before, info)
    }

    func testDragFromCardioCardScrolls() async throws {
        let (moved, info) = try await dragDown(from: app.staticTexts["近 12 週・每週跑步機分鐘"].firstMatch, dy: 60)
        XCTAssertGreaterThan(moved, 80, "從有氧卡往上捲，移動了 \(moved) pt；\(info)")
    }

    func testDragFromFrequencyChartScrolls() async throws {
        let (moved, info) = try await dragDown(from: app.staticTexts["訓練頻率"].firstMatch, dy: 140)
        XCTAssertGreaterThan(moved, 80, "從訓練頻率圖往上捲，移動了 \(moved) pt；\(info)")
    }

    func testDragFromBalanceCardScrolls() async throws {
        let (moved, info) = try await dragDown(from: app.staticTexts["平衡・近 30 天"].firstMatch, dy: -10, distance: 120)
        XCTAssertGreaterThan(moved, 60, "從平衡卡往上捲，移動了 \(moved) pt；\(info)")
    }

    private var frequencyChartPoint: XCUICoordinate {
        let title = app.staticTexts["訓練頻率"].firstMatch.frame
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.midX, dy: title.midY + 140))
    }

    /// 選取的長條：圖表的 accessibilityValue 是標籤的文字「10/19–10/25・4 次」
    private var frequencyChart: XCUIElement { app.descendants(matching: .any)["frequencyChart"].firstMatch }

    func testTapOnFrequencyChartSelects() async throws {
        XCTAssertEqual(frequencyChart.value as? String ?? "", "")
        // 剛捲完時第一下可能只會停住慣性；最多點兩次
        var value = ""
        for _ in 0..<2 where value.isEmpty {
            frequencyChartPoint.tap()
            try await Task.sleep(for: .seconds(0.5))
            value = frequencyChart.value as? String ?? ""
        }
        XCTAssertTrue(value.contains("–") && value.contains("次"), "點一下長條沒有選到：「\(value)」")
    }

    func testPressAndDragOnFrequencyChartDoesNotScroll() async throws {
        let title = app.staticTexts["訓練頻率"].firstMatch
        let before = title.frame.minY
        // 按住 0.5 秒再往左下拖：是選取，不是捲動
        frequencyChartPoint.press(forDuration: 0.5, thenDragTo: frequencyChartPoint.withOffset(CGVector(dx: -120, dy: 120)),
                                  withVelocity: .slow, thenHoldForDuration: 0.3)
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(title.frame.minY, before, accuracy: 1, "按住拖曳時畫面不該捲動")
    }

    /// 隱藏的分頁列不攔截點擊：點原本「今天」分頁按鈕的位置，還是留在歷程
    func testHiddenTabBarDoesNotInterceptTaps() async throws {
        app.terminate()
        app.launchArguments = ["-demoData", "YES", "-startTab", "1", "-historySegment", "stats"]
        app.launch()
        let today = app.buttons["今天"].firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 15))
        let spot = today.frame
        app.swipeUp(velocity: .slow)
        try await Task.sleep(for: .seconds(1.5))
        XCTAssertFalse(today.isHittable, "往下捲之後分頁列應該收起")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: spot.midX, dy: spot.midY)).tap()
        try await Task.sleep(for: .seconds(1))
        XCTAssertTrue(app.staticTexts["訓練頻率"].exists, "點到隱藏的分頁列，離開了歷程")
    }
}
