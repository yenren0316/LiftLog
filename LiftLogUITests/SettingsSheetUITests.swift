import XCTest

/// CHANGE_13 §1：分頁只剩三個；「今天」右上角的齒輪用 sheet 打開設定，能進到第 2 層、能關閉
@MainActor
final class SettingsSheetUITests: XCTestCase {
    func testGearOpensSettingsSheet() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "0"])
        let gear = app.navigationBars["今天"].buttons["設定"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 15), "今天的導覽列要有齒輪")
        try await Task.sleep(for: .seconds(1))
        XCTAssertGreaterThan(gear.frame.midX, app.frame.midX, "齒輪在右上角")
        XCTAssertLessThan(gear.frame.midY, 120, "齒輪在導覽列上")
        let tabs = app.tabBars.firstMatch.buttons
        XCTAssertEqual(tabs.count, 3, "分頁只剩今天、歷程、動作庫")
        XCTAssertFalse(tabs["設定"].exists, "沒有設定分頁")

        gear.tap()
        let settings = app.navigationBars["設定"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "點齒輪要打開設定")
        try await Task.sleep(for: .seconds(1))
        attachScreenshot("V4_settings")

        // 第 2 層：外觀
        app.buttons["外觀"].firstMatch.tap()
        let appearance = app.navigationBars["外觀"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5), "要能進到第 2 層")
        try await Task.sleep(for: .seconds(1))
        attachScreenshot("V4_settings_appearance")
        appearance.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "返回第 1 層")

        // 右上角系統的關閉按鈕
        let close = app.buttons["closeSettings"].firstMatch
        XCTAssertTrue(close.exists)
        XCTAssertGreaterThan(close.frame.midX, app.frame.midX, "關閉按鈕在右上角")
        close.tap()
        XCTAssertTrue(settings.waitForNonExistence(timeout: 5), "按關閉要關掉設定")
        let back = await gear.waitForHittable(true, timeout: 5)
        XCTAssertTrue(back, "關掉之後回到今天")

        // 再打開一次：從第 1 層開始
        gear.tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertFalse(appearance.exists, "重新打開時是第 1 層")
    }
}
