import AppIntents
import SwiftUI
import WidgetKit

// 即時動態的畫面（CHANGE_05 第 6-3、6-4 節）。放在 Shared，小工具和 App 的預覽頁共用。

typealias WorkoutActivityState = WorkoutActivityAttributes.ContentState

/// 即時動態的版面（CHANGE_08 §5）：iOS 的鎖定畫面即時動態最高 160 pt，超出的部分會被裁掉。
/// 休息和非休息的每一列都用固定高度，兩種狀態連同上下邊距一樣高（150 pt）；所有文字一行，太長用「…」截斷
nonisolated enum LiveActivityLayout {
    static let padding: CGFloat = 14
    /// 第 1 列：訓練名稱和經過時間
    static let headerHeight: CGFloat = 18
    /// 第 2、3 列：動作與組（休息時是休息、下一組、倒數和進度條）
    static let middleHeight: CGFloat = 52
    /// 第 4 列：按鈕
    static let buttonHeight: CGFloat = 36
    static let spacing: CGFloat = 8
    /// 倒數數字的大小
    static let countdownSize: CGFloat = 34

    static var lockScreenHeight: CGFloat {
        padding * 2 + headerHeight + spacing + middleHeight + spacing + buttonHeight
    }

    /// 動態島展開：上面一列由系統的左右區域放，下面只放第 2～4 列，倒數小一點
    static let islandMiddleHeight: CGFloat = 46
    static let islandCountdownSize: CGFloat = 28
}

/// 鎖定畫面：由上到下是訓練名稱和經過時間、目前的組（或休息）、按鈕
struct WorkoutActivityLockScreenView: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: LiveActivityLayout.spacing) {
            WorkoutActivityHeader(state: state)
                .frame(height: LiveActivityLayout.headerHeight)
            WorkoutActivityBody(attributes: attributes, state: state, isStale: isStale,
                                middleHeight: LiveActivityLayout.middleHeight, countdownSize: LiveActivityLayout.countdownSize)
        }
        .padding(LiveActivityLayout.padding)
        .foregroundStyle(.white)
        // 字級再大也不能超過 160 pt：文字最大到 large，其餘一律截斷
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

/// 第 1 列：訓練名稱（小字），右側是經過時間；兩種狀態位置相同
struct WorkoutActivityHeader: View {
    var state: WorkoutActivityState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(state.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(state.startedAt, style: .timer)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .frame(maxWidth: 72, alignment: .trailing)
        }
    }
}

/// 第 2～4 列：非休息時是動作與角色、「第 2／6 組・目標 60 kg × 5」、「完成這組」；
/// 休息時是「休息」和下一組（左）、倒數（右）、進度條、「跳過休息」「+15 秒」。鎖定畫面和動態島展開共用
struct WorkoutActivityBody: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool
    var middleHeight: CGFloat
    var countdownSize: CGFloat

    private var accent: Color { Color(hex: attributes.accent) }
    private var done: Color { Color(hex: attributes.done) }

    var body: some View {
        VStack(alignment: .leading, spacing: LiveActivityLayout.spacing) {
            Group {
                if let rest = state.restInterval(isStale: isStale) {
                    resting(rest)
                } else {
                    working
                }
            }
            .frame(height: middleHeight, alignment: .top)
            buttons
                .frame(height: LiveActivityLayout.buttonHeight)
        }
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private func resting(_ rest: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("休息", systemImage: "timer").font(.headline).foregroundStyle(accent)
                    if let name = state.exerciseName {
                        Text("下一組：\(name)・\(state.setText)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(timerInterval: rest, countsDown: true)
                    .font(.system(size: countdownSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: countdownSize * 3, alignment: .trailing)
            }
            ProgressView(timerInterval: rest, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(accent)
        }
    }

    @ViewBuilder
    private var working: some View {
        if let name = state.exerciseName {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let role = state.roleTitle {
                        Label(role, systemImage: state.roleSymbol ?? "dumbbell.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                            .fixedSize()
                    }
                    Text(name).font(.title3.bold())
                }
                Text("\(state.setText)・\(state.target.map { "目標 \($0)" } ?? "沒有預填值")")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("全部的組都完成了").font(.title3.bold())
                Text("已完成 \(state.completedSets)／\(state.totalSets) 組")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if state.restInterval(isStale: isStale) != nil {
            HStack(spacing: 10) {
                Button(intent: SkipRestIntent()) {
                    Label("跳過休息", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
                }
                Button(intent: ExtendRestIntent()) {
                    Label("+15 秒", systemImage: "plus").frame(maxWidth: .infinity).monospacedDigit()
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(accent)
        } else if state.hasCurrentSet, state.canComplete {
            Button(intent: CompleteSetIntent()) {
                Label("完成這組", systemImage: "checkmark")
                    .font(.headline)
                    .foregroundStyle(Palette.isLight(attributes.done) ? .black : .white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(done)
        } else {
            // 沒有預填值可用（例如第一次做的動作），或全部打勾了：在 App 裡輸入或完成
            Link(destination: DeepLink.workout.url) {
                Label(state.hasCurrentSet ? "打開 App 輸入這組" : "打開 App 完成訓練",
                      systemImage: state.hasCurrentSet ? "square.and.pencil" : "flag.checkered")
                    .font(.headline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(accent.opacity(0.18), in: .capsule)
            }
            .foregroundStyle(accent)
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
            .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

/// 動態島縮小時右邊：休息中顯示倒數，否則顯示「2/5」
struct WorkoutActivityCompactTrailing: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool

    var body: some View {
        Group {
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
        .lineLimit(1)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

/// 動態島最小（和其他即時動態並存時）：休息中顯示倒數，否則顯示啞鈴
struct WorkoutActivityMinimal: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool

    var body: some View {
        Group {
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
        .lineLimit(1)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}
