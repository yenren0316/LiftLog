import XCTest

/// CHANGE_15 §1：今天、歷程、動作庫、設定的第 1 層用 inlineLarge，大字的標題和右上角的按鈕在同一列。
/// 每個畫面量標題和按鈕的位置（存成附件 title_…）；歷程和動作庫捲下去再捲回最上面，標題留在原位、捲動時照樣在同一列。
/// 每個畫面各自啟動（捲動會讓分頁列縮小，只剩目前的分頁）
@MainActor
final class TitleBarUITests: XCTestCase {
    func testTodayTitleAndGearShareOneRow() async throws {
        let app = launch(["-startTab", "0"])
        XCTAssertTrue(app.buttons["nextCard"].firstMatch.waitForExistence(timeout: 15))
        try await check(app, title: "今天", button: app.navigationBars["今天"].buttons["設定"], shot: "V1_today", scrolls: false)
    }

    func testHistoryTitleAndMenuShareOneRow() async throws {
        let app = launch(["-startTab", "1", "-historySegment", "records"])
        try await check(app, title: "歷程", button: app.navigationBars["歷程"].buttons["更多"], shot: "V1_history")
        // 「紀錄｜統計」在標題下方
        let picker = app.segmentedControls.firstMatch
        XCTAssertGreaterThan(picker.frame.minY, app.navigationBars["歷程"].staticTexts["歷程"].frame.maxY - 1, "分段在標題下方")
    }

    func testLibraryTitleAndPlusShareOneRow() async throws {
        let app = launch(["-startTab", "2"])
        try await check(app, title: "動作庫", button: app.navigationBars["動作庫"].buttons["新增動作"], shot: "V1_library")
        let search = app.searchFields.firstMatch
        XCTAssertGreaterThan(search.frame.minY, app.navigationBars["動作庫"].staticTexts["動作庫"].frame.maxY - 1, "搜尋列在標題下方")
    }

    func testSettingsTitleAndCloseShareOneRow() async throws {
        let app = launch(["-openSettings", "YES"])
        let close = app.buttons["closeSettings"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 15))
        try await check(app, title: "設定", button: close, shot: "V1_settings", scrolls: false)
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "YES"] + arguments
        app.launch()
        return app
    }

    /// 標題和按鈕的垂直中心差不到 12 pt、標題不蓋到按鈕；捲下去時還在同一列，捲回最上面回到原位
    private func check(_ app: XCUIApplication, title: String, button: XCUIElement, shot: String, scrolls: Bool = true) async throws {
        let bar = app.navigationBars[title]
        XCTAssertTrue(bar.waitForExistence(timeout: 15), "\(title)：要有導覽列")
        try await Task.sleep(for: .seconds(1.5))
        let text = bar.staticTexts[title]
        XCTAssertTrue(text.exists && button.exists, "\(title)：要有標題和按鈕")
        let (t, b) = (text.frame, button.frame)
        let note = XCTAttachment(string: "\(title)：導覽列 \(bar.frame.minY)–\(bar.frame.maxY) pt、標題 \(t.minY)–\(t.maxY) pt（x \(t.minX)–\(t.maxX)）、"
                                 + "按鈕 \(b.minY)–\(b.maxY) pt（x \(b.minX)–\(b.maxX)）")
        note.name = "title_\(title)"
        note.lifetime = .keepAlways
        add(note)
        sameRow(t, b, title)
        attachScreenshot(shot)
        guard scrolls else { return }
        let start = app.point(x: 200, y: 600), end = app.point(x: 200, y: 300)
        start.press(forDuration: 0.05, thenDragTo: end)
        try await Task.sleep(for: .seconds(1))
        attachScreenshot("\(shot)_scrolled")
        sameRow(text.frame, button.frame, "\(title)（捲下去）")
        for _ in 0..<2 { end.press(forDuration: 0.05, thenDragTo: app.point(x: 200, y: 750)) }
        try await Task.sleep(for: .seconds(1.5))
        XCTAssertLessThan(abs(text.frame.midY - t.midY), 2, "\(title)：捲回最上面，標題回到原位（\(t.midY) → \(text.frame.midY)）")
    }

    private func sameRow(_ t: CGRect, _ b: CGRect, _ title: String) {
        XCTAssertLessThan(abs(t.midY - b.midY), 12, "\(title)：標題和按鈕要在同一列（標題 \(t.midY)、按鈕 \(b.midY)）")
        XCTAssertLessThan(t.maxX, b.minX, "\(title)：標題不會蓋到按鈕")
    }
}
