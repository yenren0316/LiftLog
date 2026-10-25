import SwiftUI

/// 訓練中畫面頂部的休息倒數：-15 秒、+15 秒、跳過
struct RestTimerBar: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        if timer.isRunning {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let remaining = timer.remaining(at: context.date)
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "timer").foregroundStyle(Theme.accent)
                        Text("休息 \(WorkoutSession.format(duration: remaining.rounded(.up)))")
                            .font(.title3.bold().monospacedDigit())
                        Spacer()
                        step("-15") { timer.adjust(by: -15) }
                        step("+15") { timer.adjust(by: 15) }
                        step("跳過") { timer.skip() }
                    }
                    ThinBar(fraction: timer.duration > 0 ? remaining / timer.duration : 0, color: Theme.accent)
                }
                .padding(14)
                .background(Theme.card, in: .rect(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.accent.opacity(0.4)))
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func step(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(Theme.field, in: .capsule)
            .buttonStyle(.plain)
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
