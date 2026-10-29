import XCTest

/// CHANGE_13 §2-5：「今天」用系統的大標題，「下一次」卡和「本週」卡都要整張在分頁列和附屬列的上方，一個畫面放得下。
/// 沒有訓練、有進行中的訓練（附屬列顯示）兩種狀態都量；量到的空隙存成附件（today_fit_…）
@MainActor
final class TodayLayoutUITests: XCTestCase {
    func testTodayFitsOneScreenWithoutAWorkout() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "0"])
        let next = app.buttons["nextCard"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1))
        XCTAssertTrue(app.navigationBars["今天"].exists, "標題是系統的導覽列")
        XCTAssertTrue(next.label.contains("下一次") && next.label.contains("開始"), "沒有訓練時是下一次的建議：\(next.label)")
        attachScreenshot("V1_today")
        assertCardsFit(app, bottom: app.tabBars.firstMatch.frame.minY, name: "today_fit_idle")
    }

    func testTodayFitsOneScreenWithAnActiveWorkout() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoWorkout", "YES"])
        // 示範訓練一開始打開訓練畫面：縮小回到「今天」
        let collapse = app.buttons["縮小"].firstMatch
        XCTAssertTrue(collapse.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1.5))
        collapse.tap()
        let bar = app.buttons["workoutMiniBar"].firstMatch
        let barShown = await bar.waitForHittable(true, timeout: 10)
        XCTAssertTrue(barShown, "要有附屬列的橫條")
        try await Task.sleep(for: .seconds(1))
        let next = app.buttons["nextCard"].firstMatch
        XCTAssertTrue(next.label.contains("進行中") && next.label.contains("繼續"), "有進行中的訓練時顯示這次的訓練：\(next.label)")
        XCTAssertFalse(next.label.contains("主項"), "不顯示下一次的建議：\(next.label)")
        attachScreenshot("V2_today_active")
        assertCardsFit(app, bottom: min(app.tabBars.firstMatch.frame.minY, bar.frame.minY), name: "today_fit_active")

        // 點卡片打開訓練畫面，再收掉示範訓練，不影響其他測試
        next.tap()
        XCTAssertTrue(collapse.waitForExistence(timeout: 5), "點「繼續」要打開訓練畫面")
        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }

    /// 兩張卡都整張在 bottom（分頁列或附屬列的上緣）上方，而且在導覽列下面
    private func assertCardsFit(_ app: XCUIApplication, bottom: CGFloat, name: String) {
        let next = app.buttons["nextCard"].firstMatch, week = app.buttons["weekCard"].firstMatch
        XCTAssertTrue(week.exists, "要有本週卡")
        let navBottom = app.navigationBars["今天"].frame.maxY
        let gap = bottom - week.frame.maxY
        let measurement = XCTAttachment(string: "導覽列底 \(navBottom) pt、下一次卡 \(next.frame.minY)–\(next.frame.maxY) pt、"
                                        + "本週卡 \(week.frame.minY)–\(week.frame.maxY) pt、下緣 \(bottom) pt、空隙 \(gap) pt")
        measurement.name = name
        measurement.lifetime = .keepAlways
        add(measurement)
        XCTAssertGreaterThanOrEqual(next.frame.minY, navBottom - 1, "下一次卡要在導覽列下面")
        XCTAssertGreaterThanOrEqual(gap, 0, "本週卡要整張在分頁列和附屬列上方：差 \(-gap) pt（卡片底 \(week.frame.maxY)、下緣 \(bottom)）")
    }
}
