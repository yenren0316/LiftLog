import SwiftUI
import SwiftData

/// 三個分頁，每個只回答一個問題（CHANGE_07 設計原則 1、4）。
/// 「設定」（App 怎麼運作？）在 CHANGE_13 §1 改成「今天」右上角的齒輪打開的 sheet
enum AppTab: Hashable, CaseIterable {
    /// 下一次該練什麼？
    case today
    /// 我練了什麼、進步了多少？
    case history
    /// 我有哪些動作？
    case library

    var title: String {
        switch self {
        case .today: "今天"
        case .history: "歷程"
        case .library: "動作庫"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "dumbbell.fill"
        case .history: "calendar"
        case .library: "list.bullet.rectangle"
        }
    }
}

/// 管理畫面的呈現：目前的分頁、訓練畫面（sheet）／縮小橫條、完成畫面、歷程的導覽路徑（訓練摘要）、訓練狀態浮窗、設定。
/// 開始訓練（包括衝突處理）在 WorkoutLauncher
@Observable
final class WorkoutCoordinator {
    var tab: AppTab = .today
    /// 打開訓練畫面（全高的 sheet，CHANGE_15 §3）；往下拖關閉或按收合時變成 false
    var isExpanded = false
    /// 剛完成的訓練摘要；有值時訓練畫面的 sheet 顯示完成畫面（不能往下拖關閉）
    var summary: WorkoutSummary?
    /// 完成時沒有任何已完成的組，整次訓練已刪除
    var showEmptyFinishNotice = false
    /// 展開訓練中畫面時直接打開「新增動作」（自由選動作）
    var openAddOnExpand = false
    /// 歷程的導覽路徑（CHANGE_14 §4）：放在這裡，補登和開發用的參數才能切到歷程、推入那次訓練的摘要頁
    var historyPath = NavigationPath()
    /// 「訓練狀態」浮窗（今天的「本週」卡打開，RootView 呈現；CHANGE_10 §3、CHANGE_13 §2-2）
    var showingTrainingStatus = false
    /// 設定的 sheet（「今天」右上角的齒輪打開，RootView 呈現；CHANGE_13 §1）
    var showingSettings = false
    /// 設定裡的導覽路徑：放在這裡，換主題重建 sheet 的內容時還停在原本那一頁；關掉時清空
    var settingsPath: [SettingsView.Page] = []
    /// 摘要頁推入後直接進入編輯（補登）；編輯畫面打開後直接打開「新增動作」
    var editOnSummaryOpen = false
    var openAddInEditor = false

    /// 從別的地方打開某一次訓練的摘要（補登、開發用的 -openSummary）：切到歷程，回到第 1 層再推入摘要頁。
    /// 歷程的紀錄和動作詳情的列在自己的 NavigationStack 裡推入，不經過這裡
    func showSummary(of session: WorkoutSession, editing: Bool = false, openAdd: Bool = false) {
        editOnSummaryOpen = editing
        openAddInEditor = openAdd
        tab = .history
        historyPath = NavigationPath([session])
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
                    .foregroundStyle(Theme.textPrimary)
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
