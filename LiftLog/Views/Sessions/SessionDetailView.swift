import SwiftUI
import SwiftData

/// 歷史訓練的完整內容：可編輯數值、新增或刪除組、修改日期、再做一次
struct SessionDetailView: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator

    var body: some View {
        WorkoutEditor(session: session) {
            header
        }
        .navigationTitle(session.startedAt.shortDate)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("再做一次", systemImage: "arrow.clockwise") {
                    coordinator.requestStart(session.orderedItems.compactMap(\.exercise), context: context)
                }
                .labelStyle(.titleAndIcon)
            }
        }
    }

    private var header: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 10) {
            TextField("訓練名稱", text: $session.title, axis: .vertical)
                .font(.title2.bold())
                .onChange(of: session.title) { WorkoutActions.save(context) }
            HStack {
                DatePicker("日期", selection: dateBinding, displayedComponents: session.hasTime ? [.date, .hourAndMinute] : .date)
                    .labelsHidden()
                Spacer()
                if let duration = session.duration {
                    Label(WorkoutSession.format(duration: duration), systemImage: "timer")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// 改日期時，結束時間與每組的完成時間一起平移，「幾天前」才會跟著變
    private var dateBinding: Binding<Date> {
        Binding {
            session.startedAt
        } set: { newDate in
            let delta = newDate.timeIntervalSince(session.startedAt)
            session.startedAt = newDate
            session.endedAt = session.endedAt?.addingTimeInterval(delta)
            for item in session.items {
                for set in item.sets {
                    set.completedAt = set.completedAt?.addingTimeInterval(delta)
                }
            }
            WorkoutActions.save(context)
        }
    }
}
