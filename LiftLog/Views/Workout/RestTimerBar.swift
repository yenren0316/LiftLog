import SwiftUI

/// 訓練中畫面頂部的休息倒數：-15 秒、+15 秒、跳過。
/// 倒數和進度條是系統的計時文字和計時進度條，自己跳秒（CHANGE_12 §1）；調整或跳過時換掉時間區間，畫面立刻更新
struct RestTimerBar: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        if let start = timer.startDate, let end = timer.endDate {
            let interval = start...end
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "timer").foregroundStyle(Theme.textSecondary)
                    Text("休息 \(Text(timerInterval: interval, countsDown: true))")
                        .font(.title3.bold().monospacedDigit())
                        .accessibilityIdentifier("restCountdown")
                    Spacer()
                    step("-15") { timer.adjust(by: -15) }
                    step("+15") { timer.adjust(by: 15) }
                    step("跳過") { timer.skip() }
                }
                ProgressView(timerInterval: interval, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(Theme.textPrimary)
            }
            .padding(14)
            .background(Theme.card, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.separator))
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func step(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(Theme.field, in: .capsule)
            .buttonStyle(.pressable)
    }
}

/// 頂部的計時器按鈕：沒在倒數時可以手動開始
struct RestTimerMenu: View {
    @Environment(RestTimer.self) private var timer
    var defaultSeconds: Int

    var body: some View {
        Menu {
            Button("開始休息 \(defaultSeconds) 秒") { timer.start(seconds: defaultSeconds) }
            ForEach([60, 90, 120, 180, 240].filter { $0 != defaultSeconds }, id: \.self) { seconds in
                Button("\(seconds) 秒") { timer.start(seconds: seconds) }
            }
            if timer.isRunning {
                Button("跳過休息", systemImage: "forward.end", role: .destructive) { timer.skip() }
            }
        } label: {
            Image(systemName: timer.isRunning ? "timer.circle.fill" : "timer")
                .foregroundStyle(timer.isRunning ? Theme.accent : Theme.textPrimary)
        }
    }
}
