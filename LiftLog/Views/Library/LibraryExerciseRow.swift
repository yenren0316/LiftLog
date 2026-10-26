import SwiftUI
import SwiftData

/// 動作庫清單的一列：名稱、標籤、「N 天前」或「未練過」、「N 次」。
/// 左滑封存／取消封存；長按合併、封存、刪除（只有沒有紀錄的動作能刪）。點一下到動作詳情
struct LibraryExerciseRow: View {
    let exercise: Exercise
    var stat: StatsSnapshot.ExerciseStat?
    /// 搜尋結果和已封存清單跨分類，副標加上分類
    var showsCategory = false

    @Environment(\.modelContext) private var context
    @Environment(LibraryRowActions.self) private var actions

    var body: some View {
        NavigationLink(value: exercise) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(exercise.name).font(.body.weight(.semibold)).lineLimit(1)
                        ForEach(exercise.tags) { Chip(text: $0.title) }
                        if exercise.isArchived { Chip(text: "封存") }
                    }
                    let last = RelativeDay.text(since: stat?.lastDate) ?? "未練過"
                    Text(showsCategory ? "\(exercise.category.title)・\(last)" : last)
                        .font(.footnote)
                        .foregroundStyle(stat?.lastDate == nil ? Theme.textSecondary
                                                               : Recency.staleness(days: Recency.daysSince(stat?.lastDate)).color)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(stat?.sessionCount ?? 0) 次")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.vertical, 2)
            .opacity(exercise.isArchived ? 0.6 : 1)
        }
        .listRowBackground(Theme.card)
        .swipeActions {
            Button(exercise.isArchived ? "取消封存" : "封存", action: toggleArchived)
                .tint(exercise.isArchived ? Theme.accent : Theme.warning)
        }
        .contextMenu {
            Button("合併到…", systemImage: "arrow.triangle.merge") { actions.mergeSource = exercise }
            Button(exercise.isArchived ? "取消封存" : "封存", systemImage: "archivebox", action: toggleArchived)
            if exercise.sessionItems.isEmpty {
                Button("刪除", systemImage: "trash", role: .destructive) { actions.deleteCandidate = exercise }
            }
        }
    }

    private func toggleArchived() {
        exercise.isArchived.toggle()
        try? context.save()
    }
}

/// 一個清單裡所有列共用的「合併到…」和刪除確認
@Observable
final class LibraryRowActions {
    var mergeSource: Exercise?
    var deleteCandidate: Exercise?
}

extension View {
    /// 動作庫的清單掛這個，列的長按選單才有合併和刪除可用
    func libraryRowActionSheets() -> some View {
        modifier(LibraryRowActionSheets())
    }
}

private struct LibraryRowActionSheets: ViewModifier {
    @State private var actions = LibraryRowActions()
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content
            .environment(actions)
            .sheet(item: $actions.mergeSource) { MergeTargetView(source: $0) }
            .confirmationDialog(
                "刪除「\(actions.deleteCandidate?.name ?? "")」？",
                isPresented: Binding(get: { actions.deleteCandidate != nil }, set: { if !$0 { actions.deleteCandidate = nil } }),
                titleVisibility: .visible,
                presenting: actions.deleteCandidate
            ) { exercise in
                Button("刪除", role: .destructive) {
                    if exercise.sessionItems.isEmpty {
                        context.delete(exercise)
                        try? context.save()
                    }
                }
            }
    }
}
