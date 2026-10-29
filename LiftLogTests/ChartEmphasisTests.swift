import Foundation
import SwiftUI
import UIKit
import Testing
@testable import LiftLog

/// CHANGE_14 §3：單一數列的圖表用強調色；長條圖選取時其他長條變淡，取消選取後恢復
@MainActor
struct ChartEmphasisTests {
    /// 顏色的 0xRRGGBB 和不透明度（App 固定深色）
    private func rgba(_ color: Color) -> (hex: UInt32, alpha: Double) {
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> UInt32 { UInt32((min(max(v, 0), 1) * 255).rounded()) }
        return (byte(r) << 16 | byte(g) << 8 | byte(b), Double(a))
    }

    @Test func singleSeriesChartsUseTheAccent() {
        // 目前主題的強調色（Theme 的 token 每次取色都讀目前的主題）
        let accent = AppTheme.load().palette.accent
        #expect(rgba(ChartEmphasis.series).hex == accent)
        #expect(rgba(ChartEmphasis.series).alpha == 1)
    }

    @Test func barsDimTheOthersWhileOneIsSelected() {
        let accent = AppTheme.load().palette.accent
        // 沒有選取：全部都是強調色
        let idle = rgba(ChartEmphasis.bar(isSelected: false, hasSelection: false))
        #expect(idle.hex == accent && idle.alpha == 1)
        // 選取時：選到的那一根維持強調色，其他的變淡（約 40%）
        let selected = rgba(ChartEmphasis.bar(isSelected: true, hasSelection: true))
        #expect(selected.hex == accent && selected.alpha == 1)
        let other = rgba(ChartEmphasis.bar(isSelected: false, hasSelection: true))
        #expect(other.hex == accent && abs(other.alpha - 0.4) < 0.01)
        // 取消選取後恢復：和沒有選取一樣
        let restored = rgba(ChartEmphasis.bar(isSelected: false, hasSelection: false))
        #expect(restored.hex == idle.hex && restored.alpha == idle.alpha)
        // 折線圖：選到的那一點放大
        #expect(ChartEmphasis.selectedPointSize > ChartEmphasis.pointSize * 2)
    }
}
