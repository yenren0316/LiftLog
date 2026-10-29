import SwiftUI
import SwiftData

/// 訓練名稱欄位：留空時顯示自動產生的名稱（訓練目的）；改過之後旁邊有「恢復自動名稱」
struct SessionTitleField: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var context
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 自動名稱是輸入框的提示文字：用主要文字的顏色，不然灰色粗體看起來像停用的（CHANGE_13 §3）
            TextField(text: $text, prompt: Text(session.automaticTitle()).foregroundStyle(Theme.textPrimary), axis: .vertical) {
                Text("訓練名稱")
            }
            .font(.title2.bold())
            .submitLabel(.done)
            .onChange(of: text) {
                // 多行的輸入框按 return 是換行：名稱不需要換行，當成「完成」收起鍵盤
                if text.contains("\n") {
                    text = text.replacingOccurrences(of: "\n", with: "")
                    dismissKeyboard()
                    return
                }
                session.setTitle(fromUserInput: text)
                WorkoutActions.save(context)
            }
            if session.isTitleCustom {
                Button("恢復自動名稱", systemImage: "arrow.uturn.backward") {
                    text = ""
                    session.restoreAutomaticTitle()
                    WorkoutActions.save(context)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .buttonStyle(.pressable)
            }
        }
        .onAppear { text = session.isTitleCustom ? session.title : "" }
    }
}
