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

extension XCUIApplication {
    /// 畫面上的座標（左上角為原點）
    func point(x: CGFloat, y: CGFloat) -> XCUICoordinate {
        coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }
}
