import SwiftUI
import SwiftData

struct TodayView: View {
    var body: some View {
        NavigationStack {
            // 以今天 0 點為界，跨日後重新進入頁面就會換成新的一天
            TodayList(dayStart: Calendar.current.startOfDay(for: .now))
                .screenBackground()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct TodayList: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [WorkoutEntry]

    init(dayStart: Date) {
        _entries = Query(
            filter: #Predicate<WorkoutEntry> { $0.date >= dayStart },
            sort: \WorkoutEntry.date
        )
    }

    var body: some View {
        List {
            Section {
                ScreenHeader(title: "今日")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if entries.isEmpty {
                Text("今天還沒有紀錄。\n到「該練什麼」挑一個動作開始吧。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .listRowBackground(Theme.card)
            } else {
                Section {
                    ForEach(entries) { entry in
                        if let exercise = entry.exercise {
                            NavigationLink {
                                LogEntryView(exercise: exercise, editing: entry)
                            } label: {
                                TodayRow(entry: entry, exercise: exercise)
                            }
                            .listRowBackground(Theme.card)
                        }
                    }
                    .onDelete(perform: delete)
                } footer: {
                    Text("點一下可編輯，向左滑可刪除")
                }
            }
        }
        .listSectionSpacing(16)
        .scrollContentBackground(.hidden)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(entries[index])
        }
        try? context.save()
    }
}

private struct TodayRow: View {
    var entry: WorkoutEntry
    var exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name).font(.title3.weight(.semibold))
                Spacer()
                Text(exercise.primaryGroup.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.field, in: .capsule)
            }
            Text(entry.summary)
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(entry.isMax ? Theme.orange : Theme.green)
            if !entry.note.isEmpty {
                Text(entry.note).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
