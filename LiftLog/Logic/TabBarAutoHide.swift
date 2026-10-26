import CoreGraphics

/// 往下滑時隱藏分頁列、往上滑或回到頂端時再出現（像 Threads）。
/// 同一個方向要連續滑超過 threshold 才切換，手指微動不會閃；頂端和底部的回彈不算。
/// 只看捲動位置，不看可捲動範圍：List 捲動時會一直重估內容高度，範圍幾乎每一格都在變。
/// 停在最底部時的位移不算往上滑：分頁列消失讓可捲動範圍變短，內容會被往下拉回最底部
nonisolated struct TabBarAutoHide: Equatable {
    private(set) var isHidden = false
    var threshold: CGFloat = 24
    /// 這段同方向捲動的起點：顯示中記最高點、隱藏中記最低點；nil 表示下一個位置只當起點
    private var anchor: CGFloat?

    /// offset：捲動位置（頂端為 0）；maxOffset：捲到最底部時的 offset；isScrolling：手指拖動或慣性滑動中
    mutating func update(offset: CGFloat, maxOffset: CGFloat, isScrolling: Bool) {
        let limit = max(maxOffset, 0)
        let y = min(max(offset, 0), limit)
        guard isScrolling, let anchor else {
            self.anchor = y
            return
        }
        if y <= threshold {
            isHidden = false
            self.anchor = y
        } else if isHidden {
            // 停在最底部時直接以目前位置當起點
            let lowest = y >= limit - 1 ? y : max(anchor, y)
            if lowest - y > threshold { isHidden = false; self.anchor = y } else { self.anchor = lowest }
        } else {
            let highest = min(anchor, y)
            if y - highest > threshold { isHidden = true; self.anchor = y } else { self.anchor = highest }
        }
    }

    /// 離開畫面（切換分頁、進入下一頁）時恢復顯示
    mutating func reset() {
        isHidden = false
        anchor = nil
    }
}
