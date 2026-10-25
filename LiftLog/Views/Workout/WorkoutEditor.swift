import SwiftUI
import SwiftData

/// 輸入中的文字（避免輸入「42.」時被格式化掉小數點）
@Observable
final class SetDrafts {
    var texts: [FieldID: String] = [:]
}

/// 一列組的推導資訊
struct SetRowInfo: Identifiable {
    var set: SetRecord
    var number: String
    var previous: SetValues?
    var placeholder: SetValues?
    var id: UUID { self.set.id }
}

/// 訓練內容的編輯器：訓練中畫面與歷史訓練詳情共用
struct WorkoutEditor<Header: View>: View {
    let session: WorkoutSession
    /// 打勾時通知（訓練中畫面用來開始休息計時）
    var onSetCompleted: (SessionExercise) -> Void = { _ in }
    @ViewBuilder var header: Header

    @Environment(\.modelContext) private var context
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @State private var drafts = SetDrafts()
    @FocusState private var focus: FieldID?

    @State private var addingExercise = false
    @State private var replacing: SessionExercise?
    @State private var confirmReplace: SessionExercise?
    @State private var confirmRemove: SessionExercise?
    @State private var editingNote: SessionExercise?
    @State private var noteText = ""
    @State private var detailExercise: Exercise?
    @State private var healthImportItem: SessionExercise?
    @State private var scrollTarget: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section { header }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                ForEach(session.orderedItems) { item in
                    if let exercise = item.exercise {
                        exerciseSection(item, exercise: exercise)
                    }
                }

                Section {
                    Button { addingExercise = true } label: {
                        Label("新增動作", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .listSectionSpacing(16)
            .environment(\.defaultMinListRowHeight, 32)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation { proxy.scrollTo(target, anchor: .top) }
                scrollTarget = nil
            }
        }
        .screenBackground()
        .toolbar { keyboardToolbar }
        #if DEBUG
        // 開發用：-openAddExercise YES 打開新增動作、-openReplace YES 打開第一個動作的換動作
        .task {
            let defaults = UserDefaults.standard
            guard defaults.bool(forKey: "openAddExercise") || defaults.bool(forKey: "openReplace") else { return }
            // 等全螢幕畫面出現後再開 sheet
            try? await Task.sleep(for: .seconds(1))
            if defaults.bool(forKey: "openAddExercise") { addingExercise = true }
            if defaults.bool(forKey: "openReplace") { replacing = session.orderedItems.first }
        }
        #endif
        .sheet(isPresented: $addingExercise) {
            AddExercisesSheet(alreadyAdded: Set(session.items.compactMap { $0.exercise?.id })) { exercises in
                // 角色依動作判定
                let items = exercises.map { WorkoutActions.add($0, to: session, in: context) }
                scrollTarget = items.last?.id
            }
        }
        .sheet(item: $replacing) { item in
            ReplaceExerciseSheet(item: item) { exercise, role in
                clearDrafts(item)
                WorkoutActions.replace(item, with: exercise, role: role, in: context)
            }
        }
        .sheet(item: $healthImportItem) { item in
            HealthImportSheet { workout in applyHealth(workout, to: item) }
        }
        .navigationDestination(item: $detailExercise) { ExerciseDetailView(exercise: $0) }
        .alert("換動作？", isPresented: isPresented($confirmReplace)) {
            Button("換動作") { replacing = confirmReplace; confirmReplace = nil }
            Button("取消", role: .cancel) { confirmReplace = nil }
        } message: {
            Text("已完成的組會一起改到新動作。")
        }
        .alert("移除「\(confirmRemove?.exercise?.name ?? "")」？", isPresented: isPresented($confirmRemove)) {
            Button("移除", role: .destructive) {
                if let item = confirmRemove { WorkoutActions.remove(item, in: context) }
                confirmRemove = nil
            }
            Button("取消", role: .cancel) { confirmRemove = nil }
        } message: {
            Text("這個動作已完成的組也會一起刪除。")
        }
        .alert("備註", isPresented: isPresented($editingNote)) {
            TextField("例如：一邊、做到沒力", text: $noteText)
            Button("儲存") {
                editingNote?.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                WorkoutActions.save(context)
                editingNote = nil
            }
            Button("取消", role: .cancel) { editingNote = nil }
        }
    }

    // MARK: - 動作卡片

    @ViewBuilder
    private func exerciseSection(_ item: SessionExercise, exercise: Exercise) -> some View {
        let rows = rowInfos(item)
        let logType = exercise.logType
        Section {
            HStack {
                Button { detailExercise = exercise } label: {
                    HStack(spacing: 6) {
                        Text(exercise.name).font(.title3.bold()).foregroundStyle(Theme.accent)
                        RoleBadge(role: item.role)
                        // 和角色同名的標籤不重複顯示
                        ForEach(exercise.tags.filter { $0.title != item.role.title }) { Chip(text: $0.title) }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                cardMenu(item, exercise: exercise)
            }
            .id(item.id)

            Text(item.role.shortGuide)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            if !item.note.isEmpty {
                Text(item.note).font(.subheadline).foregroundStyle(Theme.textSecondary)
            }

            SetHeaderRow(logType: logType, unilateral: exercise.tags.contains(.unilateral),
                         unit: unit, equipment: exercise.equipment)

            ForEach(rows) { row in
                SetRow(
                    set: row.set,
                    number: row.number,
                    previous: row.previous,
                    placeholder: row.placeholder,
                    logType: logType,
                    unit: unit,
                    text: { binding(row.set, $0) },
                    focus: $focus,
                    onToggle: { toggle(row, item: item, exercise: exercise) },
                    onKind: { kind in
                        row.set.kind = kind
                        WorkoutActions.save(context)
                    },
                    onDelete: { delete(row.set) }
                )
                .listRowBackground(row.set.isCompleted ? Theme.done.opacity(0.18) : Theme.card)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("刪除", systemImage: "trash", role: .destructive) { delete(row.set) }
                }
            }

            Button { WorkoutActions.addSet(to: item, in: context) } label: {
                Label("新增一組", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(Theme.field, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Theme.card)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
    }

    private func cardMenu(_ item: SessionExercise, exercise: Exercise) -> some View {
        let items = session.orderedItems
        let index = items.firstIndex { $0 === item } ?? 0
        return Menu {
            if exercise.logType == .cardio && HealthWorkouts.isAvailable {
                Button("從 Apple Watch 帶入", systemImage: "applewatch") { healthImportItem = item }
            }
            Button("換動作", systemImage: "arrow.triangle.2.circlepath") {
                if item.completedSets.isEmpty { replacing = item } else { confirmReplace = item }
            }
            Button("加備註", systemImage: "note.text") {
                noteText = item.note
                editingNote = item
            }
            Button("上移", systemImage: "arrow.up") { WorkoutActions.move(item, by: -1, in: context) }
                .disabled(index == 0)
            Button("下移", systemImage: "arrow.down") { WorkoutActions.move(item, by: 1, in: context) }
                .disabled(index == items.count - 1)
            Button("移除", systemImage: "trash", role: .destructive) {
                if item.completedSets.isEmpty { WorkoutActions.remove(item, in: context) } else { confirmRemove = item }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
                .frame(width: 44, height: 36)
                .contentShape(.rect)
        }
    }

    // MARK: - 推導

    /// 每一組的組號、上一次、預填值
    private func rowInfos(_ item: SessionExercise) -> [SetRowInfo] {
        var normalCount = 0
        return item.setHints().map { hint in
            if hint.set.kind == .normal { normalCount += 1 }
            return SetRowInfo(set: hint.set, number: hint.set.kind.badge(number: normalCount),
                              previous: hint.previous, placeholder: hint.placeholder)
        }
    }

    // MARK: - 動作

    private func toggle(_ row: SetRowInfo, item: SessionExercise, exercise: Exercise) -> Bool {
        let set = row.set
        if set.isCompleted {
            set.isCompleted = false
            set.completedAt = nil
            WorkoutActions.save(context)
            return true
        }
        guard WorkoutActions.complete(set, placeholder: row.placeholder, in: context) else { return false }
        clearDrafts(set)
        if focus?.set == set.id { focus = nil }
        onSetCompleted(item)
        return true
    }

    private func delete(_ set: SetRecord) {
        clearDrafts(set)
        WorkoutActions.delete(set, in: context)
    }

    private func applyHealth(_ workout: TreadmillWorkout, to item: SessionExercise) {
        let target = item.orderedSets.first { !$0.isCompleted } ?? {
            WorkoutActions.addSet(to: item, in: context)
            return item.orderedSets.last!
        }()
        target.minutes = workout.minutes
        target.speed = workout.speedKmh
        target.healthWorkoutID = workout.id
        if workout.isRunning && item.note.isEmpty { item.note = "跑步" }
        clearDrafts(target)
        WorkoutActions.save(context)
    }

    // MARK: - 欄位

    private func binding(_ set: SetRecord, _ field: SetField) -> Binding<String> {
        let id = FieldID(set: set.id, field: field)
        let unit = unit
        return Binding {
            drafts.texts[id] ?? Self.format(set, field, unit: unit)
        } set: { text in
            drafts.texts[id] = text
            Self.write(text, to: set, field, unit: unit)
            WorkoutActions.save(context)
        }
    }

    /// 重量欄以目前單位顯示與輸入，存檔一律換算成 kg
    private static func format(_ set: SetRecord, _ field: SetField, unit: WeightUnit) -> String {
        switch field {
        case .weight: set.weightKg.map { unit.format(kg: $0) } ?? ""
        case .reps: set.reps.map(String.init) ?? ""
        case .seconds: set.seconds.map(Units.number) ?? ""
        case .incline: set.incline.map(Units.number) ?? ""
        case .speed: set.speed.map(Units.number) ?? ""
        case .minutes: set.minutes.map(Units.number) ?? ""
        }
    }

    private static func write(_ text: String, to set: SetRecord, _ field: SetField, unit: WeightUnit) {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let number = Double(trimmed)
        switch field {
        case .weight: set.weightKg = number.map(unit.toKg)
        case .reps: set.reps = Int(trimmed)
        case .seconds: set.seconds = number
        case .incline: set.incline = number
        case .speed: set.speed = number
        case .minutes: set.minutes = number
        }
    }

    private func clearDrafts(_ set: SetRecord) {
        for field in SetField.allCases { drafts.texts[FieldID(set: set.id, field: field)] = nil }
    }

    private func clearDrafts(_ item: SessionExercise) {
        item.sets.forEach(clearDrafts)
    }

    // MARK: - 鍵盤快捷列

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            if focus?.field.acceptsWeightSteps == true {
                Button("-2.5") { stepWeight(-2.5) }
                Button("+2.5") { stepWeight(2.5) }
                Button("+5") { stepWeight(5) }
            }
            Spacer()
            Button("下一格", action: focusNext)
            Button("完成") { focus = nil }
                .fontWeight(.semibold)
        }
    }

    /// 以目前輸入（沒輸入就用預填）為基準加減，單位跟著全域設定（lbs 模式就是 ±2.5 lb）
    private func stepWeight(_ delta: Double) {
        guard let id = focus, let (set, placeholder) = locate(id.set) else { return }
        let base = unit.displayRounded(unit.fromKg(set.weightKg ?? placeholder?.weightKg ?? 0))
        let value = max(0, base + delta)
        drafts.texts[id] = Units.number(value)
        set.weightKg = unit.toKg(value)
        WorkoutActions.save(context)
    }

    private func focusNext() {
        let order = session.orderedItems.flatMap { item -> [FieldID] in
            let fields = SetField.fields(for: item.exercise?.logType ?? .weight)
            return item.orderedSets.filter { !$0.isCompleted }.flatMap { set in fields.map { FieldID(set: set.id, field: $0) } }
        }
        guard let current = focus, let index = order.firstIndex(of: current), index + 1 < order.count else {
            focus = nil
            return
        }
        focus = order[index + 1]
    }

    private func locate(_ setID: UUID) -> (SetRecord, SetValues?)? {
        for item in session.orderedItems {
            if let row = rowInfos(item).first(where: { $0.set.id == setID }) {
                return (row.set, row.placeholder)
            }
        }
        return nil
    }

    private func isPresented<T>(_ binding: Binding<T?>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue != nil }, set: { if !$0 { binding.wrappedValue = nil } })
    }
}

/// 動作卡片標題旁的角色標記
struct RoleBadge: View {
    var role: Role

    var body: some View {
        Text(role.title)
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .overlay(Capsule().stroke(Theme.accent, lineWidth: 1))
    }
}
