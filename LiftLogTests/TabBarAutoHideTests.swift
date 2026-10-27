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
        // 距離底部 80 pt 以內往上滑不算；離開之後連續往上滑 24 pt 才出現
        scroll(&state, [930, 900, 870], max: 940)
        #expect(state.isHidden)
        scroll(&state, [850, 840], max: 940)
        #expect(!state.isHidden)
    }

    /// CHANGE_08 T2：實機在歷程最底部卡住跳動的序列。分頁列隱藏讓可捲動範圍少 98 pt（1000 → 902），
    /// 內容被拉回時彈簧回彈超過新的底部再回來；分頁列出現又讓範圍變回來。以前會一直切換，現在都不切換
    @Test func bottomBounceSequenceNeverToggles() {
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 1000, isScrolling: false)
        scroll(&state, [300, 600, 900], max: 1000)
        #expect(state.isHidden)
        var toggles = 0
        var wasHidden = state.isHidden
        func step(_ offset: CGFloat, _ max: CGFloat) {
            state.update(offset: offset, maxOffset: max, isScrolling: true)
            if state.isHidden != wasHidden { toggles += 1; wasHidden = state.isHidden }
        }
        for _ in 0..<5 {
            // 手指還往下推：超出底部的回彈
            for offset in [960, 1010, 1040] as [CGFloat] { step(offset, 1000) }
            // 範圍變短，被拉回新的底部，回彈時低於底部 32 pt
            for offset in [1000, 950, 905, 870, 890, 902] as [CGFloat] { step(offset, 902) }
            // 範圍又變長（以前分頁列出現），手指繼續往下推
            for offset in [902, 930, 970, 1000] as [CGFloat] { step(offset, 1000) }
        }
        #expect(toggles == 0)
        #expect(state.isHidden)
    }

    @Test func noTogglingWithinEightyPointsOfTheBottom() {
        // 隱藏中：在底部 80 pt 以內往上滑 25 pt 不出現
        var hidden = TabBarAutoHide()
        hidden.update(offset: 0, maxOffset: 1000, isScrolling: false)
        scroll(&hidden, [100, 400, 950], max: 1000)
        #expect(hidden.isHidden)
        scroll(&hidden, [940, 930, 925], max: 1000)
        #expect(hidden.isHidden)
        // 顯示中：在底部 80 pt 以內往下滑（包括超出底部的回彈）不隱藏
        var shown = TabBarAutoHide()
        shown.update(offset: 925, maxOffset: 1000, isScrolling: false)
        scroll(&shown, [950, 990, 1000, 1040, 1010, 1000], max: 1000)
        #expect(!shown.isHidden)
    }

    @Test func needsTwentyFourPointsInOneDirection() {
        var state = TabBarAutoHide()
        state.update(offset: 100, maxOffset: 2000, isScrolling: false)
        // 往下 15、往上 5、往下 15：累計 25，但沒有連續 24 pt
        scroll(&state, [115, 110, 125])
        #expect(!state.isHidden)
        // 從換方向的 110 起連續往下剛好 24 pt
        scroll(&state, [134])
        #expect(state.isHidden)
        // 往上也一樣：往上 14、往下 5、往上 15 不算，從 125 起連續往上 24 pt 才出現
        scroll(&state, [120, 125, 110])
        #expect(state.isHidden)
        scroll(&state, [101])
        #expect(!state.isHidden)
    }

    @Test func flingIntoTheTopBounceShows() {
        // 快速滑回頂端時，可能一格就從中段跳進頂端的回彈（跳過頂端 24 pt 那一段），還是要出現
        var state = TabBarAutoHide()
        state.update(offset: 0, maxOffset: 2000, isScrolling: false)
        scroll(&state, [200, 600])
        #expect(state.isHidden)
        scroll(&state, [300, -30])
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

    /// CHANGE_10 §0-2：可捲動範圍短的畫面（動作庫第 1 層約 117 pt）也能切換；底部的範圍縮小，中間至少留 48 pt
    @Test func shortPagesStillToggle() {
        let state = TabBarAutoHide()
        #expect(state.bottomZone(limit: 1000) == 80)
        #expect(state.bottomZone(limit: 152) == 80)
        #expect(state.bottomZone(limit: 117) == 45)
        #expect(state.bottomZone(limit: 60) == 0)

        var short = TabBarAutoHide()
        short.update(offset: 0, maxOffset: 117, isScrolling: false)
        scroll(&short, [10, 30, 60], max: 117)
        #expect(short.isHidden)
        scroll(&short, [50, 30], max: 117)
        #expect(!short.isHidden)
        // 底部 45 pt 以內照樣不切換
        scroll(&short, [50, 75, 100], max: 117)
        #expect(!short.isHidden)
    }

    // MARK: 底部留白（CHANGE_09 §0-4）

    /// 分頁列隱藏或出現時留白不變（T2 的「版面不變」）
    @Test func tabBarTogglingKeepsTheBottomMargin() {
        var inset = BottomInset()
        inset.measured(83, tabBarHidden: false)
        #expect(inset.value == 83)
        // 隱藏的動畫：量到的值不採用
        inset.measured(34, tabBarHidden: true)
        #expect(inset.value == 83)
        // 出現的動畫：中間值不採用
        inset.measured(34, tabBarHidden: false)
        inset.measured(60, tabBarHidden: false)
        inset.measured(83, tabBarHidden: false)
        #expect(inset.value == 83)
        // 橫條沒變時，穩定之後也不改
        inset.settle(tabBarHidden: false)
        #expect(inset.value == 83)
    }

    @Test func barDisappearingShrinksTheBottomMargin() {
        var inset = BottomInset()
        // 有訓練中的橫條：分頁列 83 ＋ 橫條 56
        inset.measured(139, tabBarHidden: false)
        #expect(inset.value == 139)
        // 橫條消失：量到變小的值不直接採用（可能是動畫的中間值）…
        inset.measured(83, tabBarHidden: false)
        #expect(inset.value == 139)
        // …穩定之後重新量，留白變小
        inset.barChanged()
        inset.settle(tabBarHidden: false)
        #expect(inset.value == 83)
        // 橫條又出現：馬上變大
        inset.measured(139, tabBarHidden: false)
        inset.barChanged()
        #expect(inset.value == 139)
        inset.settle(tabBarHidden: false)
        #expect(inset.value == 139)
    }

    @Test func barChangingWhileTheTabBarIsHiddenWaitsUntilItShows() {
        var inset = BottomInset()
        inset.measured(139, tabBarHidden: false)
        // 分頁列隱藏中橫條消失：先不改
        inset.measured(34, tabBarHidden: true)
        inset.barChanged()
        inset.settle(tabBarHidden: true)
        #expect(inset.value == 139 && inset.needsRemeasure)
        // 分頁列出現、穩定之後採用新的值
        inset.measured(50, tabBarHidden: false)
        inset.measured(83, tabBarHidden: false)
        inset.settle(tabBarHidden: false)
        #expect(inset.value == 83 && !inset.needsRemeasure)
    }
}
