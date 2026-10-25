import SwiftUI
import SwiftData

/// 訓練中畫面（全螢幕），可縮小成分頁列上方的橫條
struct WorkoutView: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator

    @State private var confirmingDiscard = false
    @State private var askingIncomplete = false

    var body: some View {
        NavigationStack {
            WorkoutEditor(session: session) {
                header
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("縮小", systemImage: "chevron.down") { coordinator.isExpanded = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("捨棄訓練", systemImage: "trash", role: .destructive) { confirmingDiscard = true }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成", action: finishTapped)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.green)
                        .foregroundStyle(.black)
                }
            }
            .confirmationDialog("捨棄這次訓練？", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("捨棄訓練", role: .destructive) {
                    coordinator.isExpanded = false
                    WorkoutActions.discard(session, in: context)
                }
            } message: {
                Text("這次訓練的所有組都會刪除，無法復原。")
            }
            .confirmationDialog("還有沒打勾的組", isPresented: $askingIncomplete, titleVisibility: .visible) {
                Button("刪除未完成的組", role: .destructive) { finish(.deleteIncomplete) }
                Button("全部標為完成") { finish(.completeAll) }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var header: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 6) {
            TextField("訓練名稱", text: $session.title, axis: .vertical)
                .font(.title2.bold())
                .onChange(of: session.title) { WorkoutActions.save(context) }
            HStack(spacing: 12) {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    // 經過時間一律用 startedAt 推算
                    Label(WorkoutSession.format(duration: timeline.date.timeIntervalSince(session.startedAt)),
                          systemImage: "timer")
                        .monospacedDigit()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func finishTapped() {
        let hasIncomplete = session.items.contains { $0.sets.contains { !$0.isCompleted } }
        if hasIncomplete {
            askingIncomplete = true
        } else {
            finish(.deleteIncomplete)
        }
    }

    private func finish(_ choice: SetLogic.IncompleteChoice) {
        if WorkoutActions.finish(session, choice: choice, in: context) {
            coordinator.summary = WorkoutSummary(session: session)
        } else {
            coordinator.isExpanded = false
            coordinator.showEmptyFinishNotice = true
        }
    }
}
