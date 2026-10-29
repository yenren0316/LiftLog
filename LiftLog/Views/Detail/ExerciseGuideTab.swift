import SwiftUI
import SwiftData

/// 說明分頁：核心抗動類型、動作要點、常見錯誤、退階／進階、我的筆記（全部可編輯）
struct ExerciseGuideTab: View {
    let exercise: Exercise
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("動作說明").font(.headline).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button("編輯說明", systemImage: "pencil") { editing = true }
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                }
                field("核心抗動類型", exercise.guideCore)
                list("動作要點", exercise.guideCues, numbered: true)
                list("常見錯誤", exercise.guideMistakes, numbered: false)
                HStack(alignment: .top, spacing: 16) {
                    field("退階", exercise.guideRegression)
                    field("進階", exercise.guideProgression)
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 8) {
                Text("我的筆記").font(.headline).foregroundStyle(Theme.textSecondary)
                Text(exercise.myNotes.isEmpty ? "還沒有筆記，按上方「編輯」新增。" : exercise.myNotes)
                    .foregroundStyle(exercise.myNotes.isEmpty ? Theme.textSecondary : Theme.textPrimary)
            }
            .card()
        }
        .sheet(isPresented: $editing) {
            GuideEditView(exercise: exercise)
        }
    }

    private func field(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(Theme.textSecondary)
            Text(value.isEmpty ? "—" : value).font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func list(_ title: String, _ items: [String], numbered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(Theme.textSecondary)
            if items.isEmpty {
                Text("—")
            }
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(numbered ? "\(index + 1)." : "•")
                        .foregroundStyle(numbered ? Theme.textSecondary : Theme.danger)
                        .monospacedDigit()
                    Text(item)
                }
            }
        }
    }
}

private struct GuideEditView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var core = ""
    @State private var cues = ""
    @State private var mistakes = ""
    @State private var regression = ""
    @State private var progression = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section("核心抗動類型") {
                        TextField("例如：抗伸展", text: $core)
                    }
                    Section {
                        TextEditor(text: $cues).frame(minHeight: 120)
                    } header: {
                        Text("動作要點")
                    } footer: {
                        Text("一行一條，建議 3–5 條")
                    }
                    Section {
                        TextEditor(text: $mistakes).frame(minHeight: 80)
                    } header: {
                        Text("常見錯誤")
                    } footer: {
                        Text("一行一條，建議 2–3 條")
                    }
                    Section("退階") { TextField("退階", text: $regression, axis: .vertical) }
                    Section("進階") { TextField("進階", text: $progression, axis: .vertical) }
                    Section("我的筆記") {
                        TextEditor(text: $notes).frame(minHeight: 120)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        dismissKeyboard()
                        save()
                    }
                }
            }
            .onAppear {
                core = exercise.guideCore
                cues = exercise.guideCues.joined(separator: "\n")
                mistakes = exercise.guideMistakes.joined(separator: "\n")
                regression = exercise.guideRegression
                progression = exercise.guideProgression
                notes = exercise.myNotes
            }
        }
    }

    private func lines(_ text: String) -> [String] {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func save() {
        exercise.guideCore = core.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.guideCues = lines(cues)
        exercise.guideMistakes = lines(mistakes)
        exercise.guideRegression = regression.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.guideProgression = progression.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.myNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
        dismiss()
    }
}
