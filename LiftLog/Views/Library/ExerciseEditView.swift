import SwiftUI
import SwiftData

/// 新增（exercise 為 nil）或編輯動作
struct ExerciseEditView: View {
    var exercise: Exercise?
    var defaultCategory: ExerciseCategory = .kneeDominant

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allExercises: [Exercise]

    @State private var name = ""
    @State private var category: ExerciseCategory = .kneeDominant
    @State private var tags: Set<ExerciseTag> = []
    @State private var aliases: [String] = []
    @State private var newAlias = ""
    @State private var englishName = ""
    @State private var equipment: Equipment = .barbell
    @State private var logType: LogType = .weight
    @State private var note = ""
    @State private var isArchived = false
    @State private var customRest = false
    @State private var restSeconds = 90
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
                Group {
                    Section {
                        TextField("動作名稱", text: $name)
                            .font(.title3)
                        TextField("英文名（選填）", text: $englishName)
                            .textInputAutocapitalization(.words)
                    } footer: {
                        if nameTaken { Text("已經有同名的動作").foregroundStyle(Theme.danger) }
                    }

                    Section("分類") {
                        Picker("動作分類", selection: $category) {
                            ForEach(ExerciseCategory.allCases) { Text($0.fullTitle).tag($0) }
                        }
                        ForEach(ExerciseTag.allCases) { tag in
                            Toggle(tag.title, isOn: Binding(
                                get: { tags.contains(tag) },
                                set: { on in
                                    if on { tags.insert(tag) } else { tags.remove(tag) }
                                }
                            ))
                        }
                    }

                    Section {
                        ForEach(aliases, id: \.self) { Text($0) }
                            .onDelete { aliases.remove(atOffsets: $0) }
                        HStack {
                            TextField("新增別名", text: $newAlias)
                                .onSubmit(addAlias)
                            Button("加入", action: addAlias)
                                .disabled(newAlias.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } header: {
                        Text("別名")
                    } footer: {
                        Text("匯入舊紀錄和搜尋時會比對別名。向左滑可刪除。")
                    }

                    Section("器材與紀錄方式") {
                        Picker("器材", selection: $equipment) {
                            ForEach(Equipment.allCases) { Text($0.title).tag($0) }
                        }
                        Picker("紀錄類型", selection: $logType) {
                            ForEach(LogType.allCases) { Text($0.title).tag($0) }
                        }
                    }

                    Section {
                        Toggle("自訂休息時間", isOn: $customRest)
                        if customRest {
                            Stepper("\(restSeconds) 秒", value: $restSeconds, in: 15...600, step: 15)
                                .monospacedDigit()
                        }
                    } header: {
                        Text("休息時間")
                    } footer: {
                        Text("不自訂時依訓練中的角色：ME 主項 180 秒；DE 速度主項 60 秒；DE 爆發、下肢輔助、推、拉 90 秒；核心、補強 60 秒")
                    }

                    Section("備註") {
                        TextField("例如：注意事項、器材位置", text: $note, axis: .vertical)
                    }

                    if exercise != nil {
                        Section {
                            Toggle("封存", isOn: $isArchived)
                        } footer: {
                            Text("封存後不會出現在「該練什麼」，歷史紀錄會保留。合併與刪除請在動作庫長按該動作。")
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(exercise == nil ? "新增動作" : "編輯動作")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
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
        }
    }

    private func addAlias() {
        let alias = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !alias.isEmpty, !aliases.contains(alias), alias != trimmedName else { return }
        aliases.append(alias)
        newAlias = ""
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let exercise else {
            category = defaultCategory
            return
        }
        name = exercise.name
        category = exercise.category
        tags = Set(exercise.tags)
        aliases = exercise.aliases
        englishName = exercise.englishName
        equipment = exercise.equipment
        logType = exercise.logType
        note = exercise.note
        isArchived = exercise.isArchived
        customRest = exercise.restSeconds != nil
        restSeconds = exercise.restSeconds
            ?? Prescription.of(role: exercise.defaultRole, name: exercise.name, tags: exercise.tags).restSeconds
    }

    private func save() {
        addAlias()
        let target = exercise ?? Exercise(name: trimmedName, category: category, equipment: equipment)
        if exercise == nil { context.insert(target) }
        target.name = trimmedName
        target.category = category
        target.tags = Array(tags)
        target.aliases = aliases
        target.englishName = englishName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.equipment = equipment
        target.logType = logType
        target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        target.isArchived = isArchived
        target.restSeconds = customRest ? restSeconds : nil
        try? context.save()
        dismiss()
    }
}
