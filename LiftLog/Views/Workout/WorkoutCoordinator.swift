import SwiftUI
import SwiftData

/// 管理進行中訓練的顯示（全螢幕／縮小橫條）與開始訓練時的衝突處理
@Observable
final class WorkoutCoordinator {
    /// 全螢幕顯示訓練中畫面
    var isExpanded = false
    /// 已有進行中的訓練時，等待使用者選擇「加入」或「結束並開始新的」
    var pendingStart: [Exercise]?
    /// 剛完成的訓練摘要；有值時全螢幕畫面顯示摘要
    var summary: WorkoutSummary?
    /// 完成時沒有任何已完成的組，整次訓練已刪除
    var showEmptyFinishNotice = false

    /// 開始訓練的唯一入口：沒有進行中的訓練就直接開始；有的話先問
    func requestStart(_ exercises: [Exercise], context: ModelContext) {
        if WorkoutActions.activeSession(in: context) != nil {
            pendingStart = exercises
        } else {
            WorkoutActions.start(with: exercises, in: context)
            isExpanded = true
        }
    }

    func addToCurrent(context: ModelContext) {
        guard let exercises = pendingStart, let session = WorkoutActions.activeSession(in: context) else { return }
        for exercise in exercises {
            _ = WorkoutActions.add(exercise, to: session, in: context)
        }
        pendingStart = nil
        isExpanded = true
    }

    /// 結束目前的訓練（刪掉未完成的組）並開始新的
    func finishCurrentAndStartNew(context: ModelContext) {
        guard let exercises = pendingStart else { return }
        if let session = WorkoutActions.activeSession(in: context) {
            WorkoutActions.finish(session, choice: .deleteIncomplete, in: context)
        }
        pendingStart = nil
        WorkoutActions.start(with: exercises, in: context)
        isExpanded = true
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
                        .foregroundStyle(Theme.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title.isEmpty ? "訓練中" : session.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("訓練中 \(WorkoutSession.format(duration: context.date.timeIntervalSince(session.startedAt)))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.up").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Theme.card, in: .capsule)
                .overlay(Capsule().stroke(Theme.green.opacity(0.5)))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)
        }
    }
}

extension View {
    /// 每個分頁底部都放縮小橫條（位在分頁列上方）
    func workoutMiniBar() -> some View {
        safeAreaInset(edge: .bottom) { WorkoutMiniBar() }
    }

    /// 「已有進行中的訓練」時的選擇
    func workoutStartConflictDialog(_ coordinator: WorkoutCoordinator, context: ModelContext) -> some View {
        confirmationDialog(
            "已經有進行中的訓練",
            isPresented: Binding(get: { coordinator.pendingStart != nil }, set: { if !$0 { coordinator.pendingStart = nil } }),
            titleVisibility: .visible
        ) {
            Button("加入目前的訓練") { coordinator.addToCurrent(context: context) }
            Button("結束目前的訓練並開始新的", role: .destructive) { coordinator.finishCurrentAndStartNew(context: context) }
            Button("取消", role: .cancel) { coordinator.pendingStart = nil }
        } message: {
            Text("結束目前的訓練時，沒打勾的組會被刪除。")
        }
    }
}
