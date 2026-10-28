import XCTest

/// CHANGE_11 §4-2：訓練中鍵盤上緣的候選列。點候選會填入這一格並跳到下一格；最後一格填完收起鍵盤
@MainActor
final class CandidateBarUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 臥推當 DE 主項（有建議重量）、輔助引體向上當拉、跑步機
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoWorkout", "YES", "-demoWorkoutRoles", "dynamicEffort,pull,cardio"])
        XCTAssertTrue(app.buttons["縮小"].waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(1.5))
    }

    /// 收掉示範訓練（每個測試最後呼叫；中途失敗時，下一個測試的 launchWithoutActiveWorkout 會收掉）
    private func discardDemoWorkout() async throws {
        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }

    private var keyboardShown: Bool { app.keyboards.firstMatch.exists }

    private func waitForKeyboard(_ shown: Bool, timeout: TimeInterval = 4) async -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if keyboardShown == shown { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return keyboardShown == shown
    }

    private func field(_ id: String) -> XCUIElement { app.textFields[id].firstMatch }

    private func hasFocus(_ element: XCUIElement) -> Bool {
        (element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    /// 打開某一格的鍵盤（模擬器偶爾漏掉點擊，最多兩次）
    private func open(_ element: XCUIElement) async -> Bool {
        for _ in 0..<2 {
            element.tap()
            if await waitForKeyboard(true) { return true }
        }
        return false
    }

    func testPickFillsTheFieldAndMovesToTheNext() async throws {
        let weight = field("臥推-1-weight")
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        let opened = await open(weight)
        XCTAssertTrue(opened, "點 kg 欄要打開鍵盤")
        try await Task.sleep(for: .seconds(0.8))
        // kg 欄：5 個候選，建議重量有標示
        let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'candidate-'"))
        XCTAssertEqual(candidates.count, 5, "候選列要有 5 個數字")
        let suggested = app.buttons.matching(NSPredicate(format: "label CONTAINS '建議'")).firstMatch
        XCTAssertTrue(suggested.exists, "kg 欄要有標示「建議」的候選")
        XCTAssertFalse(app.buttons["下一格"].exists, "不該再有鍵盤列的「下一格」")
        attachScreenshot("V4_kg_candidates")
        let value = String(suggested.identifier.dropFirst("candidate-".count))
        suggested.tap()
        try await Task.sleep(for: .seconds(0.8))
        XCTAssertEqual(weight.value as? String, value, "點候選要填入這一格")
        // 跳到同一組的次數欄：臥推 DE 處方 3 下 → 1～5
        let reps = field("臥推-1-reps")
        XCTAssertTrue(keyboardShown, "跳到下一格時鍵盤要留著")
        XCTAssertTrue(hasFocus(reps), "點候選之後要跳到次數欄")
        XCTAssertEqual(candidates.allElementsBoundByIndex.map(\.identifier),
                       ["candidate-1", "candidate-2", "candidate-3", "candidate-4", "candidate-5"])
        attachScreenshot("V4_reps_candidates")
        app.buttons["candidate-3"].tap()
        try await Task.sleep(for: .seconds(0.8))
        XCTAssertEqual(reps.value as? String, "3")
        XCTAssertTrue(hasFocus(field("臥推-2-weight")), "次數欄填完跳到下一組的 kg 欄")
        // 手動輸入照常可以用
        app.typeText("42.5")
        XCTAssertEqual(field("臥推-2-weight").value as? String, "42.5")
        try await discardDemoWorkout()
    }

    func testFillingTheLastFieldDismissesTheKeyboard() async throws {
        // 跑步機那一組先打勾（用灰字預填），最後一格就是輔助引體向上最後一組的次數
        let check = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH '跑步機-' AND identifier ENDSWITH '-check'")).firstMatch
        // 跑步機在最下面，清單還沒排到時先捲下去
        for _ in 0..<4 where !(check.exists && check.isHittable) { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(check.waitForExistence(timeout: 5), "找不到跑步機那一組的打勾")
        check.tap()
        try await Task.sleep(for: .seconds(1))
        let repsFields = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH '輔助引體向上-' AND identifier ENDSWITH '-reps'"))
        let last = try XCTUnwrap(repsFields.allElementsBoundByIndex.max { $0.frame.minY < $1.frame.minY })
        let opened = await open(last)
        XCTAssertTrue(opened, "點次數欄要打開鍵盤")
        try await Task.sleep(for: .seconds(0.8))
        // 拉：處方 8～12 下
        XCTAssertTrue(app.buttons["candidate-8"].exists && app.buttons["candidate-12"].exists)
        app.buttons["candidate-10"].tap()
        let hidden = await waitForKeyboard(false)
        XCTAssertTrue(hidden, "最後一格填完要收起鍵盤")
        XCTAssertEqual(last.value as? String, "10")
        try await discardDemoWorkout()
    }
}
