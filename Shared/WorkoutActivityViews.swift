import AppIntents
import SwiftUI
import WidgetKit

// 即時動態的畫面（CHANGE_05 第 6-3、6-4 節）。放在 Shared，小工具和 App 的預覽頁共用。

typealias WorkoutActivityState = WorkoutActivityAttributes.ContentState

/// 鎖定畫面：第一行標題和經過時間，中間是目前的組或休息倒數，下方是按鈕
struct WorkoutActivityLockScreenView: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.title).font(.headline).lineLimit(1)
                Spacer(minLength: 8)
                Text(state.startedAt, style: .timer)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80, alignment: .trailing)
            }
            WorkoutActivityBody(attributes: attributes, state: state, isStale: isStale, countdownSize: 44)
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

/// 目前的組或休息倒數，加上按鈕；鎖定畫面和動態島展開共用
struct WorkoutActivityBody: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool
    var countdownSize: CGFloat

    private var accent: Color { Color(hex: attributes.accent) }
    private var done: Color { Color(hex: attributes.done) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let rest = state.restInterval(isStale: isStale) {
                HStack(alignment: .firstTextBaseline) {
                    Label("休息", systemImage: "timer").font(.headline).foregroundStyle(accent)
                    Spacer(minLength: 8)
                    Text(timerInterval: rest, countsDown: true)
                        .font(.system(size: countdownSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                ProgressView(timerInterval: rest, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(accent)
                if let name = state.exerciseName {
                    Text("下一組：\(name)・\(state.setText)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 10) {
                    Button(intent: SkipRestIntent()) {
                        Label("跳過休息", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
                    }
                    Button(intent: ExtendRestIntent()) {
                        Label("+15 秒", systemImage: "plus").frame(maxWidth: .infinity)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(accent)
            } else if let name = state.exerciseName {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let role = state.roleTitle {
                        Label(role, systemImage: state.roleSymbol ?? "dumbbell.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                    }
                    Text(name).font(.title3.bold()).lineLimit(1)
                    Spacer(minLength: 4)
                    Text("已完成 \(state.completedSets)／\(state.totalSets)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("\(state.setText)・\(state.target ?? "沒有預填值")")
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                if state.canComplete {
                    Button(intent: CompleteSetIntent()) {
                        Label("完成這組", systemImage: "checkmark")
                            .font(.headline)
                            .foregroundStyle(Palette.isLight(attributes.done) ? .black : .white)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(done)
                } else {
                    // 沒有預填值可用（例如第一次做的動作），要在 App 裡輸入
                    Link(destination: DeepLink.workout.url) {
                        Label("打開 App 輸入這組", systemImage: "square.and.pencil").font(.headline)
                    }
                    .foregroundStyle(accent)
                }
            } else {
                Text("全部的組都完成了").font(.title3.bold())
                Link(destination: DeepLink.workout.url) {
                    Label("打開 App 完成訓練", systemImage: "flag.checkered").font(.headline)
                }
                .foregroundStyle(accent)
            }
        }
    }
}

/// 動態島縮小時左邊：角色的圖示
struct WorkoutActivityCompactLeading: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState

    var body: some View {
        Image(systemName: state.roleSymbol ?? "dumbbell.fill")
            .foregroundStyle(Color(hex: attributes.accent))
    }
}

/// 動態島縮小時右邊：休息中顯示倒數，否則顯示「2/5」
struct WorkoutActivityCompactTrailing: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool

    var body: some View {
        if let rest = state.restInterval(isStale: isStale) {
            Text(timerInterval: rest, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 44)
                .foregroundStyle(Color(hex: attributes.accent))
        } else if state.hasCurrentSet {
            Text("\(state.setNumber)/\(state.setCount)").monospacedDigit()
        } else {
            Image(systemName: "checkmark").foregroundStyle(Color(hex: attributes.done))
        }
    }
}

/// 動態島最小（和其他即時動態並存時）：休息中顯示倒數，否則顯示啞鈴
struct WorkoutActivityMinimal: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool

    var body: some View {
        if let rest = state.restInterval(isStale: isStale) {
            Text(timerInterval: rest, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .frame(maxWidth: 40)
                .font(.caption2)
                .foregroundStyle(Color(hex: attributes.accent))
        } else {
            Image(systemName: "dumbbell.fill").foregroundStyle(Color(hex: attributes.accent))
        }
    }
}
