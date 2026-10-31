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
    /// 鎖定畫面第 1 列經過時間的最小寬度（放得下「1:05:30」）。小工具裡的計時文字會佔走剩下的全部寬度，
    /// 所以名稱先排、經過時間保留這個寬度（CHANGE_16 的真機截圖發現名稱被擠掉）
    static let elapsedMinWidth: CGFloat = 64

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

/// 經過時間（CHANGE_10 §0-4）：一定完整顯示，包括超過 1 小時的「1:05:30」。等寬數字、一行；
/// 空間不夠時先縮小（最小 80%），不設寬度上限（以前固定 64 pt，動態島展開時「1:05:30」被裁掉）。
/// 動態島展開時另外加 belowIfTooWide：縮小了還放不下，系統把它移到下一行
struct WorkoutActivityElapsedTime: View {
    var startedAt: Date
    var font: Font

    var body: some View {
        Text(startedAt, style: .timer)
            .font(font.monospacedDigit())
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// 第 1 列：訓練名稱（小字），右側是經過時間；每一種狀態位置相同。
/// 名稱先排（太長時截斷名稱），經過時間至少保留放得下「1:05:30」的寬度
struct WorkoutActivityHeader: View {
    var state: WorkoutActivityState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(state.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: 8)
            WorkoutActivityElapsedTime(startedAt: state.startedAt, font: .subheadline)
                .frame(minWidth: LiveActivityLayout.elapsedMinWidth, alignment: .trailing)
        }
    }
}

/// 第 2～4 列（CHANGE_16 §1）：依 Phase 顯示
/// - 下一組：「下一組：臥推・第 3／8 組」、要記錄的值（大字）、主要按鈕「完成這組」；沒有可以記錄的值時按鈕換成次要文字「打開 App 填寫」
/// - 休息：「休息」和下一組（左）、倒數（右）、進度條、「跳過休息」「+15 秒」
/// - 全部完成：「全部完成，打開 App 結束訓練」和完成組數，沒有按鈕
/// 鎖定畫面和動態島展開共用；每一種狀態的總高度都一樣
struct WorkoutActivityBody: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool
    var middleHeight: CGFloat
    var countdownSize: CGFloat
    /// 要記錄的值的字級：鎖定畫面 title2，動態島展開（中段矮一點）title3
    var valueFont: Font = .title2

    private var accent: Color { Color(hex: attributes.accent) }
    private var done: Color { Color(hex: attributes.done) }

    var body: some View {
        let phase = state.phase(isStale: isStale)
        VStack(alignment: .leading, spacing: LiveActivityLayout.spacing) {
            switch phase {
            case .resting(let rest):
                resting(rest)
                    .frame(height: middleHeight, alignment: .top)
                restButtons
                    .frame(height: LiveActivityLayout.buttonHeight)
            case .ready(let setID):
                nextSet(recordable: true)
                    .frame(height: middleHeight, alignment: .top)
                completeButton(setID: setID)
                    .frame(height: LiveActivityLayout.buttonHeight)
            case .needsInput:
                nextSet(recordable: false)
                    .frame(height: middleHeight, alignment: .top)
                Text(WorkoutActivityState.needsInputText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: LiveActivityLayout.buttonHeight)
            case .allDone, .noSets:
                finished(allDone: phase == .allDone)
                    .frame(height: middleHeight + LiveActivityLayout.spacing + LiveActivityLayout.buttonHeight)
            }
        }
        .lineLimit(1)
        .truncationMode(.tail)
    }

    /// 下一組和要記錄的值；值放不下時縮小，不截斷
    private func nextSet(recordable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            WorkoutActivityNextSetText(state: state)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
            Text(state.value ?? "—")
                .font(valueFont.bold().monospacedDigit())
                .foregroundStyle(recordable ? .primary : .secondary)
                .minimumScaleFactor(0.6)
        }
    }

    private func completeButton(setID: String) -> some View {
        Button(intent: CompleteSetIntent(setID: setID)) {
            Label(WorkoutActivityState.completeTitle, systemImage: "checkmark")
                .font(.headline)
                .foregroundStyle(Palette.isLight(attributes.done) ? .black : .white)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(done)
    }

    private func resting(_ rest: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("休息", systemImage: "timer").font(.headline).foregroundStyle(accent)
                    WorkoutActivityNextSetText(state: state)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
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

    private var restButtons: some View {
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
    }

    /// 全部完成（或還沒有任何組）：沒有按鈕，點即時動態打開 App
    private func finished(allDone: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: allDone ? "checkmark.circle.fill" : "plus.circle")
                .font(.title2)
                .foregroundStyle(allDone ? done : accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(allDone ? WorkoutActivityState.allDoneText : WorkoutActivityState.noSetsText)
                    .font(.headline)
                    .minimumScaleFactor(0.8)
                if allDone {
                    Text("已完成 \(state.completedSets)／\(state.totalSets) 組")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// 「下一組：臥推・第 3／8 組」：名稱太長時只截斷名稱，組數一定完整
struct WorkoutActivityNextSetText: View {
    var state: WorkoutActivityState

    var body: some View {
        if let name = state.exerciseName {
            HStack(spacing: 0) {
                Text("下一組：\(name)").truncationMode(.tail)
                Text("・\(state.setText)").fixedSize()
            }
            .lineLimit(1)
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

/// 動態島縮小時右邊：休息中顯示倒數，否則顯示「2/5」，全部完成時打勾；沒有按鈕（CHANGE_16 §1）
struct WorkoutActivityCompactTrailing: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool

    var body: some View {
        Group {
            switch state.phase(isStale: isStale) {
            case .resting(let rest):
                Text(timerInterval: rest, countsDown: true)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 44)
                    .foregroundStyle(Color(hex: attributes.accent))
            case .ready, .needsInput:
                Text("\(state.setNumber)/\(state.setCount)").monospacedDigit()
            case .allDone:
                Image(systemName: "checkmark").foregroundStyle(Color(hex: attributes.done))
            case .noSets:
                Text("—")
            }
        }
        .lineLimit(1)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

/// 動態島最小（和其他即時動態並存時）：休息中顯示倒數，否則顯示啞鈴；沒有按鈕
struct WorkoutActivityMinimal: View {
    var attributes: WorkoutActivityAttributes
    var state: WorkoutActivityState
    var isStale: Bool

    var body: some View {
        Group {
            if case .resting(let rest) = state.phase(isStale: isStale) {
                Text(timerInterval: rest, countsDown: true)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
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
