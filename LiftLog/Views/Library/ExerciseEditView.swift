import SwiftUI
import SwiftData

/// 新增（exercise 為 nil）或編輯動作
struct ExerciseEditView: View {
    var exercise: Exercise?
    var defaultGroup: MuscleGroup = .chest

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allExercises: [Exercise]

    @State private var name = ""
    @State private var primaryGroup: MuscleGroup = .chest
    @State private var secondaryGroups: Set<MuscleGroup> = []
    @State private var equipment: Equipment = .barbell
    @State private var logType: LogType = .weight
    @State private var note = ""
    @State private var isArchived = false
    @State private var loaded = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameTaken: Bool {
        allExercises.contains { $0.name == trimmedName && $0 !== exercise }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("動作名稱", text: $name)
                        .font(.title3)
                } footer: {
                    if nameTaken { Text("已經有同名的動作").foregroundStyle(Theme.red) }
                }

                Section("部位") {
                    Picker("主要部位", selection: $primaryGroup) {
                        ForEach(MuscleGroup.allCases) { Text($0.title).tag($0) }
                    }
                    ForEach(MuscleGroup.allCases.filter { $0 != primaryGroup }) { group in
                        Toggle("次要：\(group.title)", isOn: Binding(
                            get: { secondaryGroups.contains(group) },
                            set: { on in
                                if on { secondaryGroups.insert(group) } else { secondaryGroups.remove(group) }
                            }
                        ))
                    }
                }

                Section("器材與紀錄方式") {
                    Picker("器材", selection: $equipment) {
                        ForEach(Equipment.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("紀錄類型", selection: $logType) {
                        ForEach(LogType.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("備註") {
                    TextField("例如：注意事項、器材位置", text: $note, axis: .vertical)
                }

                if exercise != nil {
                    Section {
                        Toggle("封存", isOn: $isArchived)
                    } footer: {
                        Text("封存後不會出現在「該練什麼」，歷史紀錄會保留。")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(exercise == nil ? "新增動作" : "編輯動作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存", action: save)
                        .disabled(trimmedName.isEmpty || nameTaken)
                }
            }
            .onAppear(perform: load)
            .onChange(of: primaryGroup) { _, new in secondaryGroups.remove(new) }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let exercise else {
            primaryGroup = defaultGroup
            return
        }
        name = exercise.name
        primaryGroup = exercise.primaryGroup
        secondaryGroups = Set(exercise.secondaryGroups)
        equipment = exercise.equipment
        logType = exercise.logType
        note = exercise.note
        isArchived = exercise.isArchived
    }

    private func save() {
        let target = exercise ?? Exercise(name: trimmedName, primaryGroup: primaryGroup, equipment: equipment)
        if exercise == nil { context.insert(target) }
        target.name = trimmedName
        target.primaryGroup = primaryGroup
        // 依 enum 順序存，顯示時比較整齊
        target.secondaryGroups = MuscleGroup.allCases.filter { secondaryGroups.contains($0) }
        target.equipment = equipment
        target.logType = logType
        target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        target.isArchived = isArchived
        try? context.save()
        dismiss()
    }
}
