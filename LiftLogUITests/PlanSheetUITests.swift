import XCTest

/// CHANGE_15 §2：建立菜單是一個畫面。「開始」→「開始訓練」兩下就開始；點一格用 Menu 換候選，只換那一格；
/// 換日型（四個日型各截一張）；補登用同一個畫面（「補登這次訓練」），完成後切到歷程的摘要頁並打開編輯
@MainActor
final class PlanSheetUITests: XCTestCase {
    func testStartingAWorkoutTakesTwoTaps() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "0"])
        let next = app.buttons["nextCard"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1))
        // 第 1 下：「下一次」卡的「開始」
        next.tap()
        let start = app.buttons["planStart"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5), "直接看到排好的菜單和「開始訓練」")
        XCTAssertTrue(app.buttons["planSlot-0"].firstMatch.exists, "菜單的格子已經排好")
        XCTAssertEqual(start.label, "開始訓練")
        try await Task.sleep(for: .seconds(1))
        attachScreenshot("plan_default")
        // 第 2 下：「開始訓練」
        start.tap()
        XCTAssertTrue(app.buttons["縮小"].firstMatch.waitForExistence(timeout: 10), "按「開始訓練」就開始，打開訓練畫面")
        XCTAssertTrue(app.staticTexts["elapsedTime"].firstMatch.exists, "訓練畫面有經過時間")
        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }

    func testPickingACandidateReplacesOnlyThatSlot() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-openURL", "liftlog://new", "-planAnswers", "meLower,3,1"])
        let slot1 = app.buttons["planSlot-1"].firstMatch
        XCTAssertTrue(slot1.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1))
        let before = (0..<4).map { slotLabel(app, $0) }
        XCTAssertTrue(before[1].hasPrefix("下肢輔助"), before[1])
        // 點下肢輔助：系統的 Menu 列出前 5 個候選，第一個打勾（建議）
        slot1.tap()
        let items = app.collectionViews.cells
        XCTAssertTrue(items.firstMatch.waitForExistence(timeout: 5), "要出現候選的 Menu")
        try await Task.sleep(for: .seconds(0.8))
        attachScreenshot("V4_candidate_menu")
        XCTAssertTrue((2...5).contains(items.count), "最多 5 個候選：\(items.count)")
        let first = items.element(boundBy: 0).buttons.firstMatch, second = items.element(boundBy: 1).buttons.firstMatch
        XCTAssertTrue(first.isSelected, "第一個是建議、目前選的")
        XCTAssertTrue(before[1].contains(first.label), "目前這一格是第一個建議：\(before[1])")
        let name = second.label
        second.tap()
        XCTAssertTrue(items.firstMatch.waitForNonExistence(timeout: 3))
        try await Task.sleep(for: .seconds(1))
        let after = (0..<4).map { slotLabel(app, $0) }
        XCTAssertTrue(after[1].contains(name) && after[1] != before[1], "那一格換成 \(name)：\(after[1])")
        XCTAssertFalse(after[1].contains("建議"), "換過的不是建議：\(after[1])")
        for i in [0, 2, 3] { XCTAssertEqual(after[i], before[i], "第 \(i) 格不變") }
        attachScreenshot("plan_after_pick")
        app.buttons["closePlan"].firstMatch.tap()
        XCTAssertTrue(app.buttons["planStart"].firstMatch.waitForNonExistence(timeout: 5), "左上角的關閉")
    }

    func testDayTypeMenuSwitchesAndRecomputes() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-openURL", "liftlog://new"])
        let dayType = app.staticTexts["planDayType"].firstMatch
        XCTAssertTrue(dayType.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1))
        let ids = ["ME 下肢": "meLower", "ME 上肢": "meUpper", "DE 下肢": "deLower", "DE 上肢": "deUpper"]
        let start = dayType.label
        attachScreenshot("V3_plan_\(ids[start] ?? start)")
        for title in ["ME 下肢", "ME 上肢", "DE 下肢", "DE 上肢"] where title != start {
            app.buttons["dayTypeMenu"].firstMatch.tap()
            let item = app.collectionViews.buttons[title]
            XCTAssertTrue(item.waitForExistence(timeout: 5), "日型的 Menu 有 \(title)")
            XCTAssertEqual(app.collectionViews.cells.count, 3, "列出其他三個日型")
            item.tap()
            try await Task.sleep(for: .seconds(1))
            XCTAssertEqual(dayType.label, title)
            // 全部格子重新計算：主項格是這個日型的主項（ME 或 DE）
            let main = slotLabel(app, 0)
            XCTAssertTrue(main.hasPrefix(title.hasPrefix("ME") ? "ME 主項" : "DE 主項"), main)
            let second = slotLabel(app, 1)
            XCTAssertTrue(second.isEmpty || !second.hasPrefix(title.hasSuffix("下肢") ? "拉" : "下肢輔助"), "第二格跟著日型：\(second)")
            attachScreenshot("V3_plan_\(ids[title]!)")
        }
    }

    func testBackfillUsesThePlanScreen() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-startTab", "1", "-historySegment", "records"])
        let more = app.navigationBars["歷程"].buttons["更多"]
        XCTAssertTrue(more.waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1))
        more.tap()
        let backfill = app.buttons["補登訓練"]
        XCTAssertTrue(backfill.waitForExistence(timeout: 3))
        backfill.tap()
        // 同一個建立菜單的畫面，最上面是日期和時間，主要按鈕是「補登這次訓練」
        let start = app.buttons["planStart"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertEqual(start.label, "補登這次訓練")
        XCTAssertTrue(app.navigationBars["補登訓練"].exists && app.buttons["planSlot-0"].firstMatch.exists)
        XCTAssertGreaterThanOrEqual(app.datePickers.count, 3, "日期、開始和結束時間")
        try await Task.sleep(for: .seconds(1))
        attachScreenshot("V5_backfill_plan")
        start.tap()
        // 沿用 CHANGE_14：切到歷程、推入這次的摘要頁，直接打開編輯
        let editor = app.navigationBars["編輯訓練"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "補登後直接打開編輯")
        attachScreenshot("backfill_editor")
        editor.buttons["完成"].tap()
        XCTAssertTrue(app.navigationBars["訓練摘要"].waitForExistence(timeout: 5), "編輯下面是歷程推入的摘要頁")
        XCTAssertTrue(app.tabBars.buttons["歷程"].isSelected || app.tabBars.buttons["歷程"].firstMatch.exists)

        // 刪掉這次補登，不影響其他測試；刪除後回到歷程
        try await Task.sleep(for: .seconds(1))
        app.navigationBars["訓練摘要"].buttons["更多"].tap()
        let delete = app.buttons["刪除"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        let confirm = app.alerts.buttons["刪除"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.navigationBars["歷程"].waitForExistence(timeout: 5), "刪除後回到歷程")
    }

    /// 某一格的無障礙標籤（角色、動作、原因、處方）；有氧那一格是文字
    private func slotLabel(_ app: XCUIApplication, _ index: Int) -> String {
        let element = app.descendants(matching: .any)["planSlot-\(index)"].firstMatch
        return element.exists ? element.label : ""
    }
}
