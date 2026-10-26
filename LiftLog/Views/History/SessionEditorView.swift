import SwiftUI
import SwiftData

/// 編輯一次過去的訓練（第 3 層，全螢幕，CHANGE_07 C-3）：以訓練中的編輯器為基礎，最上方是名稱、日期、開始和結束時間。
/// 「完成」回到摘要浮窗。補登的訓練也從這裡編輯（沒有休息計時、即時動態和訓練中橫條）
struct SessionEditorView: View {
    let session: WorkoutSession
    /// 補登「自由選動作」：一打開就打開新增動作
    var openAddOnAppear = false
    var onAutoOpenedAdd: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var rejectedEnd = false
    /// 按「完成」時，沒打勾、但已經填了數字的組數（CHANGE_08 §1；CHANGE_09 §0-1 加了「繼續編輯」）
    @State private var filledCount = 0
    @State private var confirmingFilled = false

    var body: some View {
        NavigationStack {
            WorkoutEditor(session: session, openAddOnAppear: openAddOnAppear, onAutoOpenedAdd: onAutoOpenedAdd) {
                header
            }
            .navigationTitle("編輯訓練")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成", action: finishEditing)
                        .fontWeight(.semibold)
                }
            }
            .alert("有 \(filledCount) 組填了數字但沒打勾", isPresented: $confirmingFilled) {
                Button("把 \(filledCount) 組標為完成") { resolve(.complete) }
                Button("保持未完成") { resolve(.keepIncomplete) }
                // 取消（包括點對話框外面）＝繼續編輯：不改任何資料
                Button("繼續編輯", role: .cancel) { resolve(.continueEditing) }
            } message: {
                Text("沒打勾的組不會算進統計、上次日期和圖表。標為完成的組，完成時間記成這次訓練的結束時間。")
            }
            #if DEBUG
            // 開發用：-editorFinishPrompt YES 打開後自動按「完成」（截圖用）
            .task {
                if UserDefaults.standard.bool(forKey: "editorFinishPrompt") {
                    try? await Task.sleep(for: .milliseconds(800))
                    finishEditing()
                }
            }
            #endif
        }
    }

    /// 「完成」：有沒打勾、但已經填了數字的組時先詢問；完全沒填數字的組不處理
    private func finishEditing() {
        filledCount = WorkoutActions.filledIncompleteSets(in: session).count
        if filledCount > 0 {
            confirmingFilled = true
        } else {
            dismiss()
        }
    }

    private func resolve(_ choice: WorkoutActions.FilledSetsChoice) {
        if WorkoutActions.resolveFilledSets(choice, in: session, context: context) { dismiss() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            SessionTitleField(session: session)
            if session.hasTime {
                VStack(spacing: 8) {
                    timeRow("日期") {
                        DatePicker("日期", selection: binding { SessionTimeEdit.combine(day: $0, time: session.startedAt) },
                                   displayedComponents: .date)
                    }
                    timeRow("開始時間") {
                        DatePicker("開始時間", selection: binding { SessionTimeEdit.combine(day: session.startedAt, time: $0) },
                                   displayedComponents: .hourAndMinute)
                    }
                    timeRow("結束時間") {
                        DatePicker("結束時間", selection: endBinding, displayedComponents: .hourAndMinute)
                    }
                    if rejectedEnd {
                        Text("結束時間必須晚於開始時間").font(.footnote).foregroundStyle(Theme.warning)
                    }
                }
            } else {
                HStack {
                    DatePicker("日期", selection: binding { SessionTimeEdit.combine(day: $0, time: session.startedAt) },
                               displayedComponents: .date)
                        .labelsHidden()
                    Text("未記錄時間").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button("設定時間") {
                        session.setTimeFromMissing()
                        WorkoutActions.save(context)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private func timeRow(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary)
            Spacer()
            picker().labelsHidden()
        }
    }

    /// 改日期或開始時間：結束時間和所有組的完成時間一起平移
    private func binding(_ newStart: @escaping (Date) -> Date) -> Binding<Date> {
        Binding {
            session.startedAt
        } set: { value in
            session.apply(SessionTimeEdit.moveStart(session.editableTimes, to: newStart(value)))
            rejectedEnd = false
            WorkoutActions.save(context)
        }
    }

    /// 只改結束時間：必須晚於開始；超出範圍的完成時間限制在開始到結束之間
    private var endBinding: Binding<Date> {
        Binding {
            session.endedAt ?? session.startedAt
        } set: { value in
            let end = SessionTimeEdit.combine(day: session.startedAt, time: value)
            guard let times = SessionTimeEdit.setEnd(session.editableTimes, to: end) else {
                rejectedEnd = true
                return
            }
            rejectedEnd = false
            session.apply(times)
            WorkoutActions.save(context)
        }
    }
}
