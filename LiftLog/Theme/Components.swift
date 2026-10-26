import SwiftUI
import UIKit

// 共用的畫面元件，顏色都用 Theme 的 token（Shared/Theme.swift）

// MARK: - 收起鍵盤

/// 收起鍵盤：不管是哪個輸入框在輸入
@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

extension View {
    /// 鍵盤上方右側加「完成」收起鍵盤：數字鍵盤沒有 return 鍵，多行輸入的 return 是換行，不加就收不起來。
    /// 訓練中的組有自己的鍵盤列（含「完成」），不用這個
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成", action: dismissKeyboard).fontWeight(.semibold)
            }
        }
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.separator.opacity(0.6)))
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// 頁面共用的背景與文字顏色
    func screenBackground() -> some View {
        foregroundStyle(Theme.textPrimary)
            .background(Theme.background.ignoresSafeArea())
    }
}

/// 細長膠囊進度條，fraction 介於 0...1
struct ThinBar: View {
    var fraction: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.field)
                Capsule()
                    .fill(color)
                    .frame(width: max(8, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 8)
    }
}

/// 共用尺寸
enum Metrics {
    /// 主按鈕、選項膠囊、訓練中橫條的高度（全 App 一致）
    static let controlHeight: CGFloat = 50
    /// 篩選膠囊的高度
    static let capsuleHeight: CGFloat = 38
}

/// 主按鈕的外觀（Button 和 ShareLink 共用）：prominent 是 accent 實心，否則是 field 底
struct PrimaryButtonLabel: View {
    var title: String
    var systemImage: String?
    var prominent = true
    var isEnabled = true

    var body: some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(.headline)
        .foregroundStyle(prominent ? Theme.onAccent : Theme.textPrimary)
        .frame(maxWidth: .infinity, minHeight: Metrics.controlHeight)
        .background(prominent ? Theme.accent.opacity(isEnabled ? 1 : 0.4) : Theme.field, in: .capsule)
        .contentShape(.capsule)
    }
}

/// 主按鈕：全 App 只有這一種（CHANGE_07 B-4）
struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var prominent = true
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            PrimaryButtonLabel(title: title, systemImage: systemImage, prominent: prominent, isEnabled: isEnabled)
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
    }
}

/// 篩選或選項用的膠囊：全 App 只有這一種樣式。選中時 accent 底；fill 為 true 時撐滿寬度、高度同主按鈕
struct FilterCapsule: View {
    var title: String
    var isSelected: Bool
    var fill = false
    var action: () -> Void

    var body: some View {
        Button { withAnimation(.tap, action) } label: {
            Text(title)
                .font(fill ? .headline : .subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(maxWidth: fill ? .infinity : nil,
                       minHeight: fill ? Metrics.controlHeight : Metrics.capsuleHeight)
                .background(isSelected ? Theme.accent : Theme.field, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
    }
}

/// 經過時間（每秒更新）：「1:05:30」，可加前綴（「訓練中 」）
struct ElapsedTimeText: View {
    var since: Date
    var prefix = ""

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(prefix + WorkoutSession.format(duration: context.date.timeIntervalSince(since)))
                .monospacedDigit()
        }
    }
}

/// 頁面大標題列：左邊標題、右邊可選的按鈕
struct ScreenHeader<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.largeTitle.bold())
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

extension Staleness {
    var color: Color {
        switch self {
        case .never: Theme.danger
        case .fresh: Theme.done
        case .stale: Theme.warning
        case .cold: Theme.danger
        }
    }
}

extension Date {
    /// 2026/10/20
    var shortDate: String {
        formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }
}

/// 小膠囊標籤（分類、tags）
struct Chip: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Theme.field, in: .capsule)
    }
}

// MARK: - 點擊回饋與動畫

extension Animation {
    /// 點選後狀態改變的動畫（選取、打勾、篩選、新增或刪除一組…），全 App 一致
    nonisolated static let tap = Animation.snappy(duration: 0.3, extraBounce: 0.05)
}

/// 按下時微微縮小、變淡，放開時用彈簧彈回；取代 .plain，讓每次點擊都有回饋
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }

    /// 小按鈕（例如打勾）縮得明顯一點
    static func pressable(scale: CGFloat) -> PressableButtonStyle { PressableButtonStyle(scale: scale) }
}

// MARK: - 捲動時隱藏分頁列

extension View {
    /// 分頁裡的捲動畫面用：往下滑隱藏分頁列，往上滑或回到頂端時出現（像 Threads）。name 只用在 DEBUG 的紀錄
    func hidesTabBarOnScroll(_ name: String = "") -> some View {
        modifier(TabBarAutoHideModifier(name: name))
    }
}

extension EnvironmentValues {
    /// 分頁列上方「訓練中」橫條的上緣（global 座標，`.workoutMiniBar()` 設定）；沒有橫條為 nil。
    /// 橫條放在分頁的 NavigationStack 外面，它的高度不會算進裡面捲動畫面的安全區域，所以另外告訴捲動畫面
    @Entry var workoutMiniBarTop: CGFloat?
}

private struct TabBarAutoHideModifier: ViewModifier {
    var name: String
    @Environment(\.workoutMiniBarTop) private var miniBarTop
    @State private var isHidden = false
    @State private var autoHide = TabBarAutoHide()
    @State private var isScrolling = false
    @State private var phase: ScrollPhase = .idle
    /// 捲動內容底部固定留的高度，而且捲動畫面一律延伸到螢幕底部：分頁列隱藏或出現時，畫面大小和可捲動範圍都不變
    /// （CHANGE_08 §2）。包括訓練中的橫條，橫條出現或消失時重新量（CHANGE_09 §0-4）
    @State private var bottomInset = BottomInset()
    @State private var settleTask: Task<Void, Never>?
    @State private var extendedMaxY: CGFloat = 0
    @State private var safeMaxY: CGFloat = 0

    private struct Metrics: Equatable {
        var offset: CGFloat
        var maxOffset: CGFloat
        var contentHeight: CGFloat
        var viewportHeight: CGFloat
        var insetTop: CGFloat
        var insetBottom: CGFloat
    }

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, newPhase in
                phase = newPhase
                isScrolling = newPhase.isScrolling
            }
            .onScrollGeometryChange(for: Metrics.self) { geometry in
                let insets = geometry.contentInsets
                // 可視範圍用 visibleRect：ScrollView 的 containerSize 不含底部 inset，List 的含，用它算最底部會差一個 inset
                let viewport = geometry.visibleRect.height
                return Metrics(offset: geometry.contentOffset.y + insets.top,
                               maxOffset: geometry.contentSize.height + insets.top + insets.bottom - viewport,
                               contentHeight: geometry.contentSize.height, viewportHeight: viewport,
                               insetTop: insets.top, insetBottom: insets.bottom)
            } action: { _, metrics in
                autoHide.update(offset: metrics.offset, maxOffset: metrics.maxOffset, isScrolling: isScrolling)
                #if DEBUG
                TabBarAutoHideLog.geometry(name, metrics: (metrics.offset, metrics.maxOffset, metrics.contentHeight,
                                                           metrics.viewportHeight, metrics.insetTop, metrics.insetBottom),
                                           phase: phase, hidden: autoHide.isHidden)
                #endif
                if autoHide.isHidden != isHidden {
                    #if DEBUG
                    TabBarAutoHideLog.toggle(name, hidden: autoHide.isHidden, offset: metrics.offset, maxOffset: metrics.maxOffset)
                    #endif
                    withAnimation(.snappy(duration: 0.3)) { isHidden = autoHide.isHidden }
                }
            }
            // List 不吃 contentMargins 的底部留白，用 safeAreaPadding（List 和 ScrollView 都會當成內容的 inset）
            .safeAreaPadding(.bottom, bottomInset.value)
            // 捲動畫面延伸到螢幕底部：量它的底邊…
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { extendedMaxY = $0 }
            .ignoresSafeArea(.container, edges: .bottom)
            // …和原本安全區域的底邊，差距就是底部安全區域
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { safeMaxY = $0 }
            .onChange(of: obstruction, initial: true) { _, inset in
                guard extendedMaxY > 0, safeMaxY > 0 else { return }
                update { $0.measured(inset, tabBarHidden: isHidden) }
            }
            // 訓練中的橫條出現或消失：等動畫結束、分頁列顯示時重新量
            .onChange(of: miniBarTop == nil) {
                bottomInset.barChanged()
                scheduleSettle()
            }
            .onChange(of: isHidden) {
                if bottomInset.needsRemeasure { scheduleSettle() }
            }
            // 沒有要隱藏時交給系統（.automatic），下一頁的 .toolbar(.hidden, for: .tabBar) 才會生效
            .toolbarVisibility(isHidden ? .hidden : .automatic, for: .tabBar)
            // 切換分頁或進入下一頁時恢復顯示
            .onDisappear {
                autoHide.reset()
                isHidden = false
            }
    }

    /// 底部被蓋住的高度：底部安全區域（分頁列、Home 指示條），有訓練中橫條時從螢幕底部算到橫條上緣
    private var obstruction: CGFloat {
        max(extendedMaxY - safeMaxY, miniBarTop.map { extendedMaxY - $0 } ?? 0)
    }

    private func scheduleSettle() {
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            update { $0.settle(tabBarHidden: isHidden) }
        }
    }

    private func update(_ change: (inout BottomInset) -> Void) {
        #if DEBUG
        let before = bottomInset.value
        #endif
        change(&bottomInset)
        #if DEBUG
        if bottomInset.value != before { TabBarAutoHideLog.note("\(name) bottom margin = \(bottomInset.value)") }
        #endif
    }
}

#if DEBUG
import os

/// 開發用：分頁列自動隱藏的紀錄（CHANGE_08 §2 查歷程捲到底部跳動）。啟動參數 -tabBarLog YES 另外記每一格的捲動位置。
/// 看紀錄：xcrun simctl spawn <裝置> log show --last 1m --predicate 'subsystem == "com.aaronhou.LiftLog"'
enum TabBarAutoHideLog {
    private static let logger = Logger(subsystem: "com.aaronhou.LiftLog", category: "TabBarAutoHide")

    /// 每一格的捲動位置只在 -tabBarLog YES 時記（量很大）；切換一律記
    private static let logsGeometry = UserDefaults.standard.bool(forKey: "tabBarLog")

    static func geometry(_ name: String, metrics m: (offset: CGFloat, maxOffset: CGFloat, content: CGFloat, viewport: CGFloat,
                                                      top: CGFloat, bottom: CGFloat),
                         phase: ScrollPhase, hidden: Bool) {
        guard logsGeometry else { return }
        logger.notice("""
        geo \(name, privacy: .public) y=\(m.offset, format: .fixed(precision: 1)) max=\(m.maxOffset, format: .fixed(precision: 1)) \
        content=\(m.content, format: .fixed(precision: 1)) viewport=\(m.viewport, format: .fixed(precision: 1)) \
        top=\(m.top, format: .fixed(precision: 1)) bottom=\(m.bottom, format: .fixed(precision: 1)) \
        phase=\(String(describing: phase), privacy: .public) hidden=\(hidden)
        """)
    }

    static func note(_ text: String) {
        logger.notice("\(text, privacy: .public)")
    }

    static func toggle(_ name: String, hidden: Bool, offset: CGFloat, maxOffset: CGFloat) {
        logger.notice("TOGGLE \(name, privacy: .public) -> \(hidden ? "hidden" : "shown", privacy: .public) y=\(offset, format: .fixed(precision: 1)) max=\(maxOffset, format: .fixed(precision: 1))")
    }
}
#endif
