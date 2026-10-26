import CoreGraphics

/// 往下滑時隱藏分頁列、往上滑或回到頂端時再出現（像 Threads）。
/// 同一個方向要連續滑超過 threshold 才切換，手指微動不會閃；頂端和底部的回彈不算。
/// 只有使用者在捲動時才切換：分頁列出現或消失會改變可捲動的範圍（例如停在最底部時內容會跟著移動），
/// 這種位移和內容變長變短一樣，只更新基準點
nonisolated struct TabBarAutoHide: Equatable {
    private(set) var isHidden = false
    var threshold: CGFloat = 24
    /// 這段同方向捲動的起點：顯示中記最高點、隱藏中記最低點
    private var anchor: CGFloat = 0
    private var lastMaxOffset: CGFloat?

    /// offset：捲動位置（頂端為 0）；maxOffset：捲到最底部時的 offset；isScrolling：手指拖動或慣性滑動中
    mutating func update(offset: CGFloat, maxOffset: CGFloat, isScrolling: Bool) {
        let limit = max(maxOffset, 0)
        let y = min(max(offset, 0), limit)
        let rangeChanged = lastMaxOffset.map { abs($0 - limit) > 0.5 } ?? true
        lastMaxOffset = limit
        guard isScrolling, !rangeChanged else {
            anchor = y
            return
        }
        if y <= threshold {
            isHidden = false
            anchor = y
        } else if isHidden {
            anchor = max(anchor, y)
            if anchor - y > threshold { isHidden = false; anchor = y }
        } else {
            anchor = min(anchor, y)
            if y - anchor > threshold { isHidden = true; anchor = y }
        }
    }

    /// 離開畫面（切換分頁、進入下一頁）時恢復顯示
    mutating func reset() {
        isHidden = false
        lastMaxOffset = nil
    }
}
