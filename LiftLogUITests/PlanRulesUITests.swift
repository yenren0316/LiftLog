import XCTest

/// CHANGE_18：示範資料是昨天早上 ME 上肢（臥推）、昨天晚上 DE 上肢（爆發划船）。
/// - 「下一次」是 ME 下肢，主項前蹲舉沒有紀錄 → 熟悉日，預設 2 個動作（V2）
/// - 換成 DE 上肢：輪到臥推（速度），臥推昨天練過 → 借力推舉，原因「臥推（速度）昨天練過，換下一個」（V1）；預設 3 個動作、第三格是核心（V3）
/// - 照建議開始 ME 下肢：訓練畫面前蹲舉的說明列是熟悉日（V4）
@MainActor
final class PlanRulesUITests: XCTestCase {
    func testTodayAndPlanFollowTheNewRules() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "0"])
        let next = app.buttons["nextCard"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1))
        // V2：「下一次」卡
        XCTAssertTrue(next.label.contains("ME 下肢"), next.label)
        XCTAssertTrue(next.label.contains("主項：前蹲舉・熟悉日"), next.label)
        XCTAssertTrue(next.label.contains("2 個動作"), next.label)
        attachScreenshot("V2_today_familiarization")

        // V2：建立菜單的主項格是熟悉日的處方，動作數 2
        next.tap()
        let slot0 = app.descendants(matching: .any)["planSlot-0"].firstMatch
        XCTAssertTrue(slot0.waitForExistence(timeout: 5))
        try await Task.sleep(for: .seconds(1))
        XCTAssertTrue(slot0.label.contains("前蹲舉") && slot0.label.contains("熟悉日：逐步加到順手的 5 下，不衝極限"), slot0.label)
        XCTAssertTrue(app.segmentedControls["planCount"].buttons["2 個"].isSelected, "ME 日預設 2 個動作")
        XCTAssertFalse(app.descendants(matching: .any)["planSlot-2"].firstMatch.exists, "2 個動作：沒有第三格")
        attachScreenshot("V2_plan_familiarization")

        // V1、V3：換成 DE 上肢
        try await switchDayType(app, to: "DE 上肢")
        XCTAssertTrue(app.segmentedControls["planCount"].buttons["3 個"].isSelected, "DE 日預設 3 個動作")
        let main = slotLabel(app, 0)
        XCTAssertTrue(main.hasPrefix("DE 主項") && main.contains("借力推舉"), main)
        XCTAssertTrue(main.contains("臥推（速度）昨天練過，換下一個"), main)
        let third = slotLabel(app, 2)
        XCTAssertTrue(third.hasPrefix("核心"), "DE 上肢的第三格是核心：\(third)")
        attachScreenshot("V1_plan_skip_48h")
        attachScreenshot("V3_plan_de_upper_core")

        // V3：DE 下肢也是 3 個、第三格核心
        try await switchDayType(app, to: "DE 下肢")
        XCTAssertTrue(app.segmentedControls["planCount"].buttons["3 個"].isSelected)
        XCTAssertTrue(slotLabel(app, 2).hasPrefix("核心"), slotLabel(app, 2))
        attachScreenshot("V3_plan_de_lower_core")

        // ME 上肢：2 個；改成 3 個時第三格是補強
        try await switchDayType(app, to: "ME 上肢")
        XCTAssertTrue(app.segmentedControls["planCount"].buttons["2 個"].isSelected)
        app.segmentedControls["planCount"].buttons["3 個"].tap()
        try await Task.sleep(for: .seconds(1))
        XCTAssertTrue(slotLabel(app, 2).hasPrefix("補強"), slotLabel(app, 2))
        attachScreenshot("V3_plan_me_upper_accessory")
        app.buttons["closePlan"].firstMatch.tap()
        XCTAssertTrue(app.buttons["planStart"].firstMatch.waitForNonExistence(timeout: 5))
    }

    /// V4：照建議開始 ME 下肢，訓練畫面前蹲舉的說明列是熟悉日；最後捨棄這次訓練
    func testWorkoutCardShowsTheFamiliarizationDay() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "0"])
        let next = app.buttons["nextCard"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1))
        next.tap()
        let start = app.buttons["planStart"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        try await Task.sleep(for: .seconds(1))
        start.tap()
        XCTAssertTrue(app.buttons["縮小"].firstMatch.waitForExistence(timeout: 10), "打開訓練畫面")
        let line = app.staticTexts["熟悉日：逐步加到順手的 5 下，不衝極限・充分休息"].firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5), "前蹲舉的說明列是熟悉日")
        XCTAssertTrue(app.staticTexts["設好安全槓"].firstMatch.exists, "安全提示照舊")
        try await Task.sleep(for: .seconds(1))
        attachScreenshot("V4_workout_familiarization")
        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }

    private func switchDayType(_ app: XCUIApplication, to title: String) async throws {
        app.buttons["dayTypeMenu"].firstMatch.tap()
        let item = app.collectionViews.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "日型的 Menu 有 \(title)")
        item.tap()
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(app.staticTexts["planDayType"].firstMatch.label, title)
    }

    private func slotLabel(_ app: XCUIApplication, _ index: Int) -> String {
        let element = app.descendants(matching: .any)["planSlot-\(index)"].firstMatch
        return element.exists ? element.label : ""
    }
}
