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

    @Test func listHeightEstimatesDoNotBlockHiding() {
        // List 捲動時一直重估內容高度：可捲動範圍每一格都不一樣，照樣要能隱藏和出現（曾經因此完全不會隱藏）
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 3000, isScrolling: false)
        for (i, offset) in stride(from: 10, through: 200, by: 10).enumerated() {
            state.update(offset: CGFloat(offset), maxOffset: 3000 + CGFloat(i * 37 % 90), isScrolling: true)
        }
        #expect(state.isHidden)
        for (i, offset) in stride(from: 190, through: 150, by: -10).enumerated() {
            state.update(offset: CGFloat(offset), maxOffset: 3100 - CGFloat(i * 23 % 70), isScrolling: true)
        }
        #expect(!state.isHidden)
    }

    @Test func barLeavingAtTheBottomDoesNotBringItBack() {
        // 滑到最底部時分頁列消失，可捲動範圍變短，內容被拉回新的最底部：不算往上滑（曾經會彈出來一下又消失）
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 1000, isScrolling: false)
        scroll(&state, [300, 700, 980], max: 1000)
        #expect(state.isHidden)
        for limit in stride(from: 990, through: 940, by: -10) {
            state.update(offset: CGFloat(limit), maxOffset: CGFloat(limit), isScrolling: true)
        }
        #expect(state.isHidden)
        // 從最底部往上滑才出現
        scroll(&state, [930, 920], max: 940)
        #expect(state.isHidden)
        scroll(&state, [910], max: 940)
        #expect(!state.isHidden)
    }

    @Test func movesWhileNotScrollingOnlyMoveTheStartingPoint() {
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 1000, isScrolling: false)
        scroll(&state, [300, 700], max: 1000)
        #expect(state.isHidden)
        // 沒在捲動時的位移（例如收合一個區塊）不算
        state.update(offset: 500, maxOffset: 800, isScrolling: false)
        scroll(&state, [490])
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
