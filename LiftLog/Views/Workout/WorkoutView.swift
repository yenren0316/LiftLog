import SwiftUI
import SwiftData

/// 訓練中畫面（全螢幕），可縮小成分頁列上方的橫條
struct WorkoutView: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Environment(RestTimer.self) private var restTimer
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg

    @State private var confirmingDiscard = false
    @State private var askingIncomplete = false

    var body: some View {
        NavigationStack {
            WorkoutEditor(session: session, openAddOnAppear: coordinator.openAddOnExpand,
                          onAutoOpenedAdd: { coordinator.openAddOnExpand = false }, onSetCompleted: setCompleted) {
                header
            } footer: {
                // 最後一個動作下面的紅字按鈕（CHANGE_10 §0-3，取代右上角的 ••• 選單）
                Button("捨棄訓練", role: .destructive) { confirmingDiscard = true }
                    .font(.headline)
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .safeAreaInset(edge: .top) { RestTimerBar() }
            .animation(.snappy, value: restTimer.isRunning)
            .sensoryFeedback(.success, trigger: restTimer.finishedCount)
            #if DEBUG
            // 開發用：啟動參數 -demoRest 90 開始休息倒數
            .task {
                let seconds = UserDefaults.standard.integer(forKey: "demoRest")
                if seconds > 0, !restTimer.isRunning { restTimer.start(seconds: seconds) }
            }
            #endif
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("縮小", systemImage: "chevron.down") { coordinator.isExpanded = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    RestTimerMenu(defaultSeconds: session.orderedItems.last?.restSeconds ?? 90)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成", action: finishTapped)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .foregroundStyle(Theme.onAccent)
                }
            }
            .alert("捨棄這次訓練？", isPresented: $confirmingDiscard) {
                Button("取消", role: .cancel) { WorkoutActions.resolveDiscard(.cancel, session: session, in: context) }
                Button("捨棄訓練", role: .destructive) {
                    restTimer.skip()
                    coordinator.isExpanded = false
                    WorkoutActions.resolveDiscard(.discard, session: session, in: context)
                }
            } message: {
                Text("這次訓練的所有組都會刪除，無法復原。")
            }
            .alert("還有沒打勾的組", isPresented: $askingIncomplete) {
                Button("刪除未完成的組", role: .destructive) { finish(.deleteIncomplete) }
                Button("全部標為完成") { finish(.completeAll) }
                Button("取消", role: .cancel) {}
            } message: {
                Text("全部標為完成時，沒填的欄位用灰字的預填值；連預填值都沒有的組會刪除。")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SessionTitleField(session: session)
            HStack(spacing: 12) {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                // 經過時間一律用 startedAt 推算
                Label { ElapsedTimeText(since: session.startedAt).accessibilityIdentifier("elapsedTime") } icon: { Image(systemName: "timer") }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private func finishTapped() {
        dismissKeyboard()
        let hasIncomplete = session.items.contains { $0.sets.contains { !$0.isCompleted } }
        if hasIncomplete {
            askingIncomplete = true
        } else {
            finish(.deleteIncomplete)
        }
    }

    /// 打勾後自動開始休息倒數（設定頁可關閉）；和即時動態的「完成這組」同一套邏輯
    private func setCompleted(_ item: SessionExercise) {
        WorkoutService.shared.startRest(after: item)
    }

    private func finish(_ choice: SetLogic.IncompleteChoice) {
        restTimer.skip()
        if WorkoutActions.finish(session, choice: choice, in: context) {
            coordinator.summary = WorkoutSummary(session: session, unit: unit)
        } else {
            coordinator.isExpanded = false
            coordinator.showEmptyFinishNotice = true
        }
    }
}
