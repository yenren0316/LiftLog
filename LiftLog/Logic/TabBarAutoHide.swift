import CoreGraphics

/// 往下滑時隱藏分頁列、往上滑或回到頂端時再出現（像 Threads）。CHANGE_08 §2 的規則：
/// - 同一個方向要「連續」滑至少 threshold（24 pt）才切換；中途換方向就從換方向的地方重新算。
/// - 距離底部 bottomZone（80 pt）以內，或底部回彈中（捲動位置超出內容範圍）時不切換。
///   以前在底部會形成循環：分頁列隱藏 → 可捲動範圍變短 → 內容被拉回、回彈時看起來像往上滑 → 分頁列出現 → 範圍又變長…
///   可捲動範圍短的畫面（例如動作庫第 1 層，約 120 pt），底部的範圍縮小，中間至少留 48 pt（兩段 24 pt）可以切換（CHANGE_10 §0-2）。
/// - 頂端附近（threshold 以內）一律顯示；頂端往下拉的回彈也顯示（快速滑回頂端時可能直接跳進回彈，跳過頂端那一段）。
/// - 只在使用者捲動中（拖動、慣性、捲動動畫）才切換；其他原因的位移（版面重算、收合區塊）只當作新的起點。
nonisolated struct TabBarAutoHide: Equatable {
    private(set) var isHidden = false
    var threshold: CGFloat = 24
    var bottomZone: CGFloat = 80
    /// 上一個位置；nil 表示下一個位置只當起點
    private var lastY: CGFloat?
    /// 這一段同方向捲動的起點
    private var runStart: CGFloat = 0
    /// 這一段的方向：1 往下、-1 往上、0 還沒動
    private var direction: CGFloat = 0

    /// offset：捲動位置（頂端為 0，回彈時會小於 0 或大於 maxOffset）；maxOffset：捲到最底部時的 offset；
    /// isScrolling：手指拖動、慣性滑動或捲動動畫中
    mutating func update(offset: CGFloat, maxOffset: CGFloat, isScrolling: Bool) {
        let limit = max(maxOffset, 0)
        guard isScrolling, let last = lastY else {
            restart(at: min(max(offset, 0), limit))
            return
        }
        // 頂端：一律顯示（包括往下拉的回彈）
        if offset <= threshold {
            isHidden = false
            restart(at: max(offset, 0))
            return
        }
        // 底部回彈中，或距離底部 bottomZone 以內：不切換，離開之後從這裡重新算
        if offset > limit || limit - offset <= bottomZone(limit: limit) {
            restart(at: min(offset, limit))
            return
        }
        let delta = offset - last
        guard delta != 0 else { return }
        let step: CGFloat = delta > 0 ? 1 : -1
        if step != direction {
            direction = step
            runStart = last
        }
        lastY = offset
        guard abs(offset - runStart) >= threshold else { return }
        if step > 0, !isHidden {
            isHidden = true
            runStart = offset
        } else if step < 0, isHidden {
            isHidden = false
            runStart = offset
        }
    }

    /// 底部不切換的範圍：最多 bottomZone；可捲動範圍短時縮小，頂端 threshold 以下至少留 2 × threshold 可以切換
    func bottomZone(limit: CGFloat) -> CGFloat {
        min(bottomZone, max(0, limit - 3 * threshold))
    }

    /// 離開畫面（切換分頁、進入下一頁）時恢復顯示
    mutating func reset() {
        isHidden = false
        lastY = nil
        direction = 0
    }

    private mutating func restart(at y: CGFloat) {
        lastY = y
        runStart = y
        direction = 0
    }
}

/// 捲動內容底部固定留的高度（CHANGE_08 §2、CHANGE_09 §0-4）：分頁列顯示時量到的底部被蓋住的高度
/// （分頁列、Home 指示條、訓練中的橫條）。分頁列隱藏或出現時不變，版面才不會跟著跳。
/// - 分頁列隱藏時量到的值不採用；平常只增不減（分頁列出現的動畫過程中的中間值不採用）。
/// - 訓練中的橫條出現或消失後，等畫面穩定、分頁列顯示時，直接採用最近量到的值（可以變小）。
nonisolated struct BottomInset: Equatable {
    private(set) var value: CGFloat = 0
    /// 最近一次分頁列顯示時量到的高度
    private(set) var latest: CGFloat = 0
    /// 橫條出現或消失之後還沒重新量
    private(set) var needsRemeasure = false

    mutating func measured(_ inset: CGFloat, tabBarHidden: Bool) {
        guard !tabBarHidden, inset > 0 else { return }
        latest = inset
        value = max(value, inset)
    }

    /// 訓練中的橫條出現或消失
    mutating func barChanged() {
        needsRemeasure = true
    }

    /// 畫面穩定之後呼叫：橫條變過、而且分頁列顯示中，就採用最近量到的值
    mutating func settle(tabBarHidden: Bool) {
        guard needsRemeasure, !tabBarHidden, latest > 0 else { return }
        value = latest
        needsRemeasure = false
    }
}
