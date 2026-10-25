import SwiftUI

/// 一次訓練的完整內容（第 5 階段會改成可編輯）
struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            ForEach(session.orderedItems) { item in
                Section(item.exercise?.name ?? "（已刪除的動作）") {
                    Text(item.summary)
                }
            }
        }
        .navigationTitle(session.title)
    }
}
