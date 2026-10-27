import SwiftUI
import UIKit
import Charts

// 圖表的選取手勢（CHANGE_10 §0-1）：全 App 的圖表（有氧、訓練頻率、體重、動作詳情的折線圖）都用這一個。
// 點一下選取；按住約 0.2 秒後才能拖曳選取。手指一開始就移動時按住的手勢失敗，上下滑一律交給捲動。
// 以前用 SwiftUI 的 LongPressGesture.sequenced(before: DragGesture(minimumDistance: 0))：
// 手指從圖表上開始時，整頁捲不動（歷程統計頁捲到底部後，從訓練頻率卡開始往上滑沒有反應）

extension View {
    /// 圖表的 x 軸是日期時用這個：手指的位置換成日期寫進 selected。
    /// 點一下選取，hideAfter 之後消失（nil 時一直留著）；按住拖曳跟著手指，放開後同樣依 hideAfter（nil 時留著，否則馬上消失）
    func chartDateSelection(_ selected: Binding<Date?>, hideAfter: Duration? = .seconds(2)) -> some View {
        modifier(ChartDateSelection(selected: selected, hideAfter: hideAfter))
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
    var hideAfter: Duration?
    @State private var hideTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(.rect)
                    .chartSelectionGestures { location in
                        select(location, proxy: proxy, geometry: geometry)
                        if let hideAfter { hide(after: hideAfter) }
                    } onDrag: { location in
                        hideTask?.cancel()
                        select(location, proxy: proxy, geometry: geometry)
                    } onDragEnd: {
                        if hideAfter != nil { hide(after: .zero) }
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
