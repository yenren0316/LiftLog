import SwiftUI
import SwiftData

/// 四個分頁，每個只回答一個問題（CHANGE_07 設計原則 1、4）
enum AppTab: Hashable, CaseIterable {
    /// 下一次該練什麼？
    case today
    /// 我練了什麼、進步了多少？
    case history
    /// 我有哪些動作？
    case library
    /// App 怎麼運作？
    case settings

    var title: String {
        switch self {
        case .today: "今天"
        case .history: "歷程"
        case .library: "動作庫"
        case .settings: "設定"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "dumbbell.fill"
        case .history: "calendar"
        case .library: "list.bullet.rectangle"
        case .settings: "gearshape.fill"
        }
    }
}

/// 管理畫面的呈現：目前的分頁、「今天」的導覽路徑、訓練中全螢幕／縮小橫條、完成摘要、訓練摘要浮窗。
/// 開始訓練（包括衝突處理）在 WorkoutLauncher
@Observable
final class WorkoutCoordinator {
    var tab: AppTab = .today
    /// 「今天」分頁的導覽路徑（liftlog://today 會清空，回到第 1 層）
    var todayPath = NavigationPath()
    /// 全螢幕顯示訓練中畫面
    var isExpanded = false
    /// 剛完成的訓練摘要；有值時全螢幕畫面顯示摘要
    var summary: WorkoutSummary?
    /// 完成時沒有任何已完成的組，整次訓練已刪除
    var showEmptyFinishNotice = false
    /// 展開訓練中畫面時直接打開「新增動作」（自由選動作）
    var openAddOnExpand = false
    /// 訓練摘要浮窗（RootView 呈現，任何畫面都可以打開）
    var summarySession: WorkoutSession?
    /// 「訓練狀態」浮窗（今天的日曆卡打開，RootView 呈現；CHANGE_10 §3）
    var showingTrainingStatus = false
    /// 浮窗打開後直接進入編輯（補登）；編輯畫面打開後直接打開「新增動作」
    var editOnSummaryOpen = false
    var openAddInEditor = false

    func showSummary(of session: WorkoutSession, editing: Bool = false, openAdd: Bool = false) {
        editOnSummaryOpen = editing
        openAddInEditor = openAdd
        summarySession = session
    }
}

/// 「訓練中 0:42」橫條，放在系統的分頁列附屬列（`tabViewBottomAccessory`，CHANGE_11 §1）裡，點一下展開。
/// 外框、背景和位置都交給系統：分頁列展開時在分頁列上方（expanded），縮小時和分頁列同一列（inline）
struct WorkoutMiniBar: View {
    let session: WorkoutSession
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        Button { coordinator.isExpanded = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(Theme.accent)
                if placement == .inline {
                    // 和縮小的分頁列同一列，空間只夠一行
                    ElapsedTimeText(since: session.startedAt, prefix: "訓練中 ")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(session.title.isEmpty ? "訓練中" : session.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        ElapsedTimeText(since: session.startedAt, prefix: "訓練中 ")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up").foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("workoutMiniBar")
    }
}

extension View {
    /// 有進行中的訓練時，在分頁列的附屬列放「訓練中」橫條；沒有時用系統的 isEnabled 隱藏附屬列（iOS 26.1 起）
    @ViewBuilder
    func workoutMiniBar(_ session: WorkoutSession?) -> some View {
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: session != nil) {
                if let session { WorkoutMiniBar(session: session) }
            }
        } else if let session {
            // iOS 26.0 沒有 isEnabled：只在有訓練時加上附屬列
            tabViewBottomAccessory { WorkoutMiniBar(session: session) }
        } else {
            self
        }
    }
}
