import XCTest

/// CHANGE_07 V1：「今天」一個畫面放得下——近 30 天的卡片整張在分頁列上方，不用捲動。
/// CHANGE_12 §3 試過系統的大標題：卡片底部超出分頁列 32.5 pt，照規格停下來，標題照舊是 ScreenHeader；
/// 這個測試量目前的版面，量到的空隙存成附件（today_fit）
@MainActor
final class TodayLayoutUITests: XCTestCase {
    func testTodayFitsOneScreen() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "0"])
        let card = app.otherElements["recentSetsCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1))
        attachScreenshot("V1_today")
        let tabBarTop = app.tabBars.firstMatch.frame.minY
        let gap = tabBarTop - card.frame.maxY
        let measurement = XCTAttachment(string: "卡片底 \(card.frame.maxY) pt、分頁列頂 \(tabBarTop) pt、空隙 \(gap) pt")
        measurement.name = "today_fit"
        measurement.lifetime = .keepAlways
        add(measurement)
        XCTAssertGreaterThanOrEqual(gap, 0,
            "近 30 天的卡片要整張在分頁列上方：差 \(-gap) pt（卡片底 \(card.frame.maxY)、分頁列頂 \(tabBarTop)）")
    }
}
