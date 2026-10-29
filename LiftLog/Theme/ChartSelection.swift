import SwiftUI
import UIKit
import Charts

// 圖表的選取手勢（CHANGE_10 §0-1）：全 App 的圖表（有氧、訓練頻率、體重、動作詳情的折線圖）都用這一個，行為也都一樣
// （CHANGE_11 §5）：點一下浮出那一點的數字，2 秒後消失；按住約 0.2 秒再拖曳，數字跟著手指，放開後 2 秒消失。
// 手指一開始就移動時按住的手勢失敗，上下滑一律交給捲動。
// 以前用 SwiftUI 的 LongPressGesture.sequenced(before: DragGesture(minimumDistance: 0))：
// 手指從圖表上開始時，整頁捲不動（歷程統計頁捲到底部後，從訓練頻率卡開始往上滑沒有反應）

/// 圖表的顏色（CHANGE_14 §3）：圖表是資料，不是狀態。單一數列的圖表（主項進步的迷你折線、體重的線和點、有氧的長條、
/// 動作詳情的折線和點）用強調色；按部位分的訓練頻率用部位色。格線、座標軸、圖表上的文字維持中性色。
/// 選取時：折線圖選到的那一點放大（PeekLabel 浮出數字）；長條圖選到的那一根維持強調色，其他的變淡。選取消失後恢復
enum ChartEmphasis {
    /// 單一數列的顏色
    static let series = Theme.accent
    /// 長條圖有選取時，沒選到的長條的不透明度
    static let dimmedOpacity = 0.4
    /// 折線圖的點，和選到的那一點（放大）
    static let pointSize: CGFloat = 36
    static let selectedPointSize: CGFloat = 130

    /// 長條的顏色：沒有選取時全部都是強調色；有選取時選到的那一根維持，其他的變淡
    static func bar(isSelected: Bool, hasSelection: Bool) -> Color {
        series.opacity(hasSelection && !isSelected ? dimmedOpacity : 1)
    }
}

extension View {
    /// 圖表的 x 軸是日期時用這個：手指的位置換成日期寫進 selected，2 秒後清掉
    func chartDateSelection(_ selected: Binding<Date?>) -> some View {
        modifier(ChartDateSelection(selected: selected))
    }

    /// 放在圖表的 chartOverlay 裡、蓋滿圖表的透明圖層上；位置是這個圖層的座標
    func chartSelectionGestures(onTap: @escaping (CGPoint) -> Void,
                                onDrag: @escaping (CGPoint) -> Void,
                                onDragEnd: @escaping () -> Void) -> some View {
        gesture(SpatialTapGesture().onEnded { onTap($0.location) })
            .gesture(PressThenDragGesture(onChanged: onDrag, onEnded: onDragEnd))
    }
}

/// 按住 minimumDuration 之後才開始的拖曳：UIKit 的長按，開始之後手指移動會持續回報位置。
/// 按住之前手指移動超過 10 pt 就失敗，不會擋住捲動；開始之後畫面不會跟著捲
struct PressThenDragGesture: UIGestureRecognizerRepresentable {
    var minimumDuration: TimeInterval = 0.2
    var onChanged: (CGPoint) -> Void
    var onEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumDuration
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: onChanged(context.converter.localLocation)
        case .ended, .cancelled: onEnded()
        default: break
        }
    }
}

private struct ChartDateSelection: ViewModifier {
    @Binding var selected: Date?
    @State private var hideTask: Task<Void, Never>?
    /// 點一下之後、放開手指之後，數字留多久
    private static let hideAfter: Duration = .seconds(2)

    func body(content: Content) -> some View {
        content.chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(.rect)
                    .chartSelectionGestures { location in
                        select(location, proxy: proxy, geometry: geometry)
                        hide(after: Self.hideAfter)
                    } onDrag: { location in
                        hideTask?.cancel()
                        select(location, proxy: proxy, geometry: geometry)
                    } onDragEnd: {
                        hide(after: Self.hideAfter)
                    }
            }
        }
    }

    private func select(_ location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plot = proxy.plotFrame else { return }
        selected = proxy.value(atX: location.x - geometry[plot].origin.x, as: Date.self)
    }

    private func hide(after delay: Duration) {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            selected = nil
        }
    }
}
