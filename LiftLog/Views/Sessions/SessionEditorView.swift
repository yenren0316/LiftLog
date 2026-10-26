import SwiftUI
import SwiftData

/// 編輯一次過去的訓練（第 3 層，全螢幕）：以訓練中的編輯器為基礎，上方是名稱和時間。「完成」回到摘要浮窗
struct SessionEditorView: View {
    let session: WorkoutSession
    /// 補登「自由選動作」：一打開就打開新增動作
    var openAddOnAppear = false
    var onAutoOpenedAdd: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WorkoutEditor(session: session, openAddOnAppear: openAddOnAppear, onAutoOpenedAdd: onAutoOpenedAdd) {
                header
            }
            .navigationTitle("編輯訓練")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var header: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 10) {
            TextField("訓練名稱", text: $session.title, axis: .vertical)
                .font(.title2.bold())
                .onChange(of: session.title) { WorkoutActions.save(context) }
            DatePicker("日期", selection: dateBinding, displayedComponents: session.hasTime ? [.date, .hourAndMinute] : .date)
                .labelsHidden()
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
            for set in session.items.flatMap(\.sets) {
                set.completedAt = set.completedAt?.addingTimeInterval(delta)
            }
            WorkoutActions.save(context)
        }
    }
}
