import SwiftUI
import SwiftData

/// 訓練分頁（第 5 階段完成）
struct SessionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            List {
                Button("開始空白訓練") { coordinator.requestStart([], context: context) }
                ForEach(sessions.filter { !$0.isActive }) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(session.title)
                            Text(session.startedAt.shortDate).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("訓練")
        }
    }
}
