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

/// 分頁列上方的「訓練中 0:42」橫條，點一下展開
struct WorkoutMiniBar: View {
    let session: WorkoutSession
    @Environment(WorkoutCoordinator.self) private var coordinator

    var body: some View {
        Button { coordinator.isExpanded = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title.isEmpty ? "訓練中" : session.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    ElapsedTimeText(since: session.startedAt, prefix: "訓練中 ")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.up").foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 18)
            .frame(height: Metrics.controlHeight)
            .background(Theme.card, in: .capsule)
            .overlay(Capsule().stroke(Theme.accent.opacity(0.5)))
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .buttonStyle(.pressable)
    }
}

/// 有進行中的訓練、而且沒有展開成全螢幕時，在底部放縮小橫條；同時告訴裡面的捲動畫面橫條的上緣（底部留白用）
private struct WorkoutMiniBarModifier: ViewModifier {
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil }) private var active: [WorkoutSession]
    @State private var barTop: CGFloat?

    func body(content: Content) -> some View {
        let session = coordinator.isExpanded ? nil : active.first
        content
            .environment(\.workoutMiniBarTop, session == nil ? nil : barTop)
            .safeAreaInset(edge: .bottom) {
                if let session {
                    WorkoutMiniBar(session: session)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { barTop = $0 }
                }
            }
    }
}

extension View {
    /// 每個分頁底部都放縮小橫條（位在分頁列上方）
    func workoutMiniBar() -> some View {
        modifier(WorkoutMiniBarModifier())
    }
}
