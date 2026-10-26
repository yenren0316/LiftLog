import CoreGraphics
import Testing
@testable import LiftLog

/// 往下滑隱藏分頁列、往上滑出現
struct TabBarAutoHideTests {
    /// 依序捲到每個位置（使用者捲動中）
    private func scroll(_ state: inout TabBarAutoHide, _ offsets: [CGFloat], max: CGFloat = 2000) {
        for offset in offsets { state.update(offset: offset, maxOffset: max, isScrolling: true) }
    }

    @Test func hidesAfterScrollingDownPastTheThreshold() {
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 2000, isScrolling: false)
        scroll(&state, [10, 30])
        #expect(!state.isHidden)
        scroll(&state, [40])
        #expect(state.isHidden)
    }

    @Test func showsAfterScrollingUpPastTheThreshold() {
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 2000, isScrolling: false)
        scroll(&state, [100, 400, 800])
        #expect(state.isHidden)
        // 往上一點點不算
        scroll(&state, [790, 785])
        #expect(state.isHidden)
        // 又往下滑：起點跟著更新
        scroll(&state, [900])
        scroll(&state, [880])
        #expect(state.isHidden)
        scroll(&state, [870])
        #expect(!state.isHidden)
    }

    @Test func alwaysShowsNearTheTop() {
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 2000, isScrolling: false)
        scroll(&state, [100])
        #expect(state.isHidden)
        scroll(&state, [90, 80, 20])
        #expect(!state.isHidden)
        // 頂端往下拉的回彈
        scroll(&state, [-40, -10, 0])
        #expect(!state.isHidden)
    }

    @Test func bounceAtTheBottomDoesNotShow() {
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 1000, isScrolling: false)
        scroll(&state, [300, 700, 1000], max: 1000)
        #expect(state.isHidden)
        // 超過底部再彈回來
        scroll(&state, [1060, 1030, 1000], max: 1000)
        #expect(state.isHidden)
    }

    @Test func layoutChangesOnlyMoveTheStartingPoint() {
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 1000, isScrolling: false)
        scroll(&state, [300, 700, 1000], max: 1000)
        #expect(state.isHidden)
        // 分頁列消失讓可捲動範圍變短，停在底部的內容跟著往上移：不算往上滑
        scroll(&state, [970, 950], max: 950)
        #expect(state.isHidden)
        // 沒在捲動時的位移（例如展開一個區塊）也不算
        state.update(offset: 900, maxOffset: 950, isScrolling: false)
        scroll(&state, [890])
        #expect(state.isHidden)
    }

    @Test func resetShowsAgain() {
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 2000, isScrolling: false)
        scroll(&state, [100])
        #expect(state.isHidden)
        state.reset()
        #expect(!state.isHidden)
        // 回來時第一個位置只當作起點
        scroll(&state, [500, 510])
        #expect(!state.isHidden)
    }
}
