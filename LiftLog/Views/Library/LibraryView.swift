import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var showingNew = false
    @State private var showArchived = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScreenHeader(title: "動作庫") {
                        CircleIconButton(systemName: "plus") { showingNew = true }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                ForEach(MuscleGroup.allCases) { group in
                    let items = exercises.filter { $0.primaryGroup == group && !$0.isArchived }
                    if !items.isEmpty {
                        Section(group.title) {
                            ForEach(items) { row($0) }
                        }
                    }
                }

                let archived = exercises.filter(\.isArchived)
                if !archived.isEmpty {
                    Section {
                        Toggle("顯示已封存（\(archived.count)）", isOn: $showArchived)
                            .listRowBackground(Theme.card)
                        if showArchived {
                            ForEach(archived) { row($0) }
                        }
                    }
                }
            }
            .listSectionSpacing(16)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNew) {
                ExerciseEditView(exercise: nil)
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        NavigationLink {
            ExerciseDetailView(exercise: exercise)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).font(.body.weight(.semibold))
                    Text(exercise.equipment.title + (exercise.logType == .weight ? "" : " · \(exercise.logType.title)"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(exercise.entries.count) 筆")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Theme.card)
        .swipeActions {
            Button(exercise.isArchived ? "取消封存" : "封存") {
                exercise.isArchived.toggle()
                try? context.save()
            }
            .tint(exercise.isArchived ? Theme.green : Theme.yellow)
        }
    }
}
