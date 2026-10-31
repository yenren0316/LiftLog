import XCTest

/// CHANGE_16 §1：模擬器上真的即時動態按「完成這組」。intent 由系統在 App 的程序裡執行（App 在背景，或完全關掉時由系統帶起來），
/// 即時動態切到休息；打開 App 時訓練畫面已經是那一組打勾、休息倒數在跑。結束後捨棄示範訓練。
/// 示範訓練的第一個動作是臥推（示範資料有上一次，灰字預填夠完成）
@MainActor
final class LiveActivityUITests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// 動態島展開（App 在背景）
    func testCompleteSetFromTheExpandedIsland() async throws {
        let app = try await startDemoWorkout()
        XCUIDevice.shared.press(.home)
        try await Task.sleep(for: .seconds(2))
        try await pressCompleteOnTheIsland(screenshot: "V2_island_real")
        try await verifyTheAppShowsTheCompletedSet(app, relaunch: false)
    }

    /// App 完全關掉時：系統把 App 帶起來執行 intent，下次打開時從資料庫和休息計時器讀出來
    func testCompleteSetWhenTheAppIsClosed() async throws {
        let app = try await startDemoWorkout()
        XCUIDevice.shared.press(.home)
        try await Task.sleep(for: .seconds(1))
        app.terminate()
        try await Task.sleep(for: .seconds(2))
        try await pressCompleteOnTheIsland(screenshot: "island_app_closed")
        try await verifyTheAppShowsTheCompletedSet(app, relaunch: true)
    }

    /// 鎖定畫面（模擬器沒有設定密碼）：鎖定後在鎖定畫面按「完成這組」，不解鎖就切到休息；解鎖後打開 App 已經同步
    func testCompleteSetOnTheLockScreen() async throws {
        // 經過 1:05:30：第 1 列的訓練名稱和超過 1 小時的經過時間都要完整
        let app = try await startDemoWorkout(extra: ["-demoWorkoutElapsed", "3930"])
        // XCUIDevice 沒有公開的鎖定方法，用模擬器的側邊按鈕（只在測試裡用）：按一下鎖定，再按一下亮起鎖定畫面
        pressLockButton()
        try await Task.sleep(for: .seconds(2))
        pressLockButton()
        try await Task.sleep(for: .seconds(2))
        // 乾淨安裝後第一次在鎖定畫面顯示，系統會問「要允許來自 LiftLog 的即時動態嗎？」
        let allow = springboard.buttons["允許"]
        if allow.exists {
            allow.tap()
            try await Task.sleep(for: .seconds(1))
        }
        let complete = springboard.buttons["完成這組"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "鎖定畫面的即時動態沒有「完成這組」")
        attachScreenshot("V1_lock_real_ready")
        complete.tap()
        allowNotificationsIfAsked(timeout: 3)
        XCTAssertTrue(springboard.buttons["跳過休息"].waitForExistence(timeout: 8), "鎖定畫面按「完成這組」之後沒有切到休息")
        XCTAssertFalse(springboard.buttons["完成這組"].exists)
        attachScreenshot("V1_lock_real_resting")
        // 解鎖（沒有密碼：回到主畫面），打開 App
        XCUIDevice.shared.press(.home)
        try await Task.sleep(for: .seconds(1))
        XCUIDevice.shared.press(.home)
        try await Task.sleep(for: .seconds(1))
        try await verifyTheAppShowsTheCompletedSet(app, relaunch: false)
    }

    // MARK: - 共用

    private func pressLockButton() {
        _ = XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
    }

    /// 乾淨的示範訓練，訓練畫面打開著，臥推第 1 組還沒打勾
    private func startDemoWorkout(extra: [String] = []) async throws -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoWorkout", "YES"] + extra)
        XCTAssertTrue(app.buttons["縮小"].waitForExistence(timeout: 15))
        let check = app.buttons["臥推-1-check"]
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        XCTAssertEqual(check.value as? String, "未完成")
        // 即時動態建立後才回主畫面
        try await Task.sleep(for: .seconds(2))
        return app
    }

    /// 長按動態島展開，按「完成這組」，等即時動態切到休息
    private func pressCompleteOnTheIsland(screenshot name: String) async throws {
        try await expandIsland()
        let complete = springboard.buttons["完成這組"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "展開的動態島沒有「完成這組」")
        XCTAssertTrue(springboard.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "下一組：臥推")).firstMatch.exists
                      || springboard.otherElements.containing(NSPredicate(format: "label CONTAINS %@", "下一組：臥推")).firstMatch.exists,
                      "展開的動態島沒有「下一組：臥推」")
        attachScreenshot("\(name)_ready")
        complete.tap()
        // 第一次休息倒數會問通知權限（對話框在 SpringBoard）
        allowNotificationsIfAsked(timeout: 3)
        var resting = springboard.buttons["跳過休息"].waitForExistence(timeout: 8)
        if !resting {
            // 動態島可能已經收起：再展開一次看
            try await expandIsland()
            resting = springboard.buttons["跳過休息"].waitForExistence(timeout: 5)
        }
        attachScreenshot("\(name)_resting")
        XCTAssertTrue(resting, "按「完成這組」之後即時動態沒有切到休息")
        XCTAssertFalse(springboard.buttons["完成這組"].exists, "休息時不應該有「完成這組」")
        // 收起動態島
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).tap()
        try await Task.sleep(for: .seconds(1))
    }

    private func expandIsland() async throws {
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.025)).press(forDuration: 1.2)
        try await Task.sleep(for: .seconds(1.5))
    }

    /// 打開 App：臥推第 1 組打勾、第 2 組沒有，休息倒數在跑；最後捨棄示範訓練
    private func verifyTheAppShowsTheCompletedSet(_ app: XCUIApplication, relaunch: Bool) async throws {
        if relaunch {
            app.launchArguments = []
            app.launch()
        } else {
            app.activate()
        }
        if !app.buttons["縮小"].waitForExistence(timeout: 5) {
            // 訓練畫面收起來了：點附屬列的橫條打開
            let bar = app.buttons["workoutMiniBar"].firstMatch
            XCTAssertTrue(bar.waitForExistence(timeout: 10))
            bar.tap()
        }
        let first = app.buttons["臥推-1-check"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        attachScreenshot(relaunch ? "app_after_closed" : "app_after_island")
        XCTAssertEqual(first.value as? String, "已完成", "鎖定畫面完成的組沒有反映在訓練畫面")
        XCTAssertEqual(app.buttons["臥推-2-check"].value as? String, "未完成", "只應該完成一組")
        XCTAssertTrue(app.staticTexts["restCountdown"].waitForExistence(timeout: 3), "休息倒數沒有反映在訓練畫面")

        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }
}
