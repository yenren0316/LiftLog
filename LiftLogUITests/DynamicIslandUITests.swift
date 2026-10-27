import XCTest

/// CHANGE_10 §0-4：動態島（模擬器上的真的動態島）。訓練經過 1:05:30 時，縮小、展開的截圖；
/// 結束後捨棄示範訓練
@MainActor
final class DynamicIslandUITests: XCTestCase {
    func testElapsedTimeOverAnHour() async throws {
        try await capture(elapsed: 3930, name: "island")
    }

    func testElapsedTimeUnderAnHour() async throws {
        try await capture(elapsed: 1470, name: "island_short")
    }

    private func capture(elapsed: Int, name: String) async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchWithoutActiveWorkout(["-demoData", "YES", "-demoWorkout", "YES", "-demoWorkoutElapsed", "\(elapsed)"])
        XCTAssertTrue(app.buttons["縮小"].waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(2))
        // 回到主畫面：動態島縮小
        XCUIDevice.shared.press(.home)
        try await Task.sleep(for: .seconds(2))
        attachScreenshot("\(name)_compact")
        // 長按動態島：展開
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.025)).press(forDuration: 1.2)
        try await Task.sleep(for: .seconds(1.5))
        attachScreenshot("\(name)_expanded")
        // 收起，捨棄示範訓練
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).tap()
        app.terminate()
        app.launchArguments = ["-discardActive", "YES"]
        app.launch()
        try await Task.sleep(for: .seconds(3))
    }
}
