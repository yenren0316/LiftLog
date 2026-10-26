import SwiftUI
import SwiftData

/// 管理訓練相關畫面的呈現：訓練中全螢幕／縮小橫條、完成摘要、訓練摘要浮窗。
/// 開始訓練（包括衝突處理）在 WorkoutLauncher
@Observable
final class WorkoutCoordinator {
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
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil }) private var active: [WorkoutSession]

    var body: some View {
        if let session = active.first, !coordinator.isExpanded {
            Button { coordinator.isExpanded = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title.isEmpty ? "訓練中" : session.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("訓練中 \(WorkoutSession.format(duration: context.date.timeIntervalSince(session.startedAt)))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.up").foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Theme.card, in: .capsule)
                .overlay(Capsule().stroke(Theme.accent.opacity(0.5)))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            .buttonStyle(.pressable)
        }
    }
}

extension View {
    /// 每個分頁底部都放縮小橫條（位在分頁列上方）
    func workoutMiniBar() -> some View {
        safeAreaInset(edge: .bottom) { WorkoutMiniBar() }
    }
}
