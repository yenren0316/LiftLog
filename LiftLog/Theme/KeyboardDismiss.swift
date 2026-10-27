import SwiftUI
import UIKit

// 收起鍵盤（CHANGE_10 §1）：拿掉 CHANGE_08 加在鍵盤上方的「完成」，改成三種方式——
// 1. 可以捲動的畫面往下捲時收起：scrollDismissesKeyboard(.interactively)，從 RootView 和各 sheet 往下傳。
// 2. 點輸入框以外的地方收起：window 上的點擊手勢（KeyboardDismissOnTap），不攔截點擊，
//    所有畫面和 sheet 都適用，包括不能捲動的記錄體重。
// 3. 按下儲存、完成這類主要按鈕時先收起鍵盤再執行：PrimaryButton 和各 sheet 的儲存。
// 訓練名稱按 return 收起鍵盤（SessionTitleField）；訓練中的組有自己的鍵盤列（-2.5／+2.5／+5、下一格、完成）。

/// 收起鍵盤：不管是哪個輸入框在輸入
@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// 放在 RootView 的背景：在 window 上裝一次點擊手勢，點到輸入框以外的地方就收起鍵盤
struct KeyboardDismissOnTap: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, !(window.gestureRecognizers ?? []).contains(where: { $0 is KeyboardDismissTap }) else { return }
            window.addGestureRecognizer(KeyboardDismissTap())
        }
    }
}

/// 點一下就收起鍵盤：不取消點擊（按鈕、列照常反應），可以和其他手勢同時辨識；點在輸入框上不收
final class KeyboardDismissTap: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    init() {
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(tapped))
        cancelsTouchesInView = false
        delaysTouchesEnded = false
        delegate = self
    }

    @objc private func tapped() {
        dismissKeyboard()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
