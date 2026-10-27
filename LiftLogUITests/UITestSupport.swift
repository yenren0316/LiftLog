import XCTest

extension XCTestCase {
    /// 截圖存進測試結果（xcresulttool export attachments 取出），名稱用來辨識
    @MainActor
    func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCUIElement {
    /// 在 timeout 內等到 isHittable 變成 expected（分頁列收起和出現有動畫）
    @MainActor
    func waitForHittable(_ expected: Bool = true, timeout: TimeInterval = 3) async -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if (exists && isHittable) == expected { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return (exists && isHittable) == expected
    }
}

extension XCUIApplication {
    /// 畫面上的座標（左上角為原點）
    func point(x: CGFloat, y: CGFloat) -> XCUICoordinate {
        coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }
}
