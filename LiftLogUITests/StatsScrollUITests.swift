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
        let info = "start y=\(Int(y)) title y=\(Int(before))"
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.midX, dy: y))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                    withVelocity: .default, thenHoldForDuration: 0.2)
        try await Task.sleep(for: .seconds(1.5))
        return (title.frame.minY - before, info)
    }

    func testDragFromCardioCardScrolls() async throws {
        // CHANGE_13 §2-4 平衡卡變長：捲到底部時有氧卡在畫面上方之外，先慢慢往回拖（不帶慣性）到看得到有氧卡
        let caption = app.staticTexts["近 12 週・每週跑步機分鐘"].firstMatch
        for _ in 0..<4 where caption.frame.minY < 150 {
            let start = app.point(x: app.frame.midX, y: app.frame.midY - 100)
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 300)),
                        withVelocity: .slow, thenHoldForDuration: 0.5)
            try await Task.sleep(for: .seconds(1))
        }
        let (moved, info) = try await dragDown(from: caption, dy: 60)
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
}
