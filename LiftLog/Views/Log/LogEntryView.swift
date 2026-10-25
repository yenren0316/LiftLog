import SwiftUI
import SwiftData

/// 新增或編輯一筆紀錄。新增時預填上次的數字。
struct LogEntryView: View {
    let exercise: Exercise
    var editing: WorkoutEntry?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var useLbs = false
    @State private var weightText = ""
    @State private var reps = 5
    @State private var sets = 5
    @State private var isMax = false
    @State private var note = ""
    @State private var date = Date.now
    @State private var inclineText = ""
    @State private var speedText = ""
    @State private var minutesText = ""
    @State private var loaded = false
    @State private var healthWorkout: TreadmillWorkout?
    @State private var healthWorkoutID: UUID?
    @State private var showingHealthImport = false

    private var logType: LogType { exercise.logType }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if logType == .cardio {
                    cardioCard
                } else {
                    weightCard
                    countsCard
                }
                extrasCard
                saveButton
                RecentEntriesCard(exercise: exercise)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    Image(systemName: "chart.xyaxis.line")
                }
            }
        }
        .onAppear(perform: loadInitialValues)
    }

    // MARK: Cards

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(logType == .assisted ? "輔助重量" : "重量")
                    .font(.headline).foregroundStyle(.secondary)
                if let hint = exercise.equipment.weightHint {
                    Text(hint)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.field, in: .capsule)
                }
                Spacer()
                Picker("單位", selection: unitBinding) {
                    Text("kg").tag(false)
                    Text("lbs").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.green)
                Text(useLbs ? "lbs" : "kg")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                // 輔助重量越小越進步，所以快速鍵是減
                let sign: Double = logType == .assisted ? -1 : 1
                ForEach([1.25, 2.5, 5], id: \.self) { step in
                    Button {
                        adjustWeight(by: sign * step)
                    } label: {
                        Text("\(sign > 0 ? "+" : "−")\(Units.number(step))")
                            .font(.headline.monospacedDigit())
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.field, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private var countsCard: some View {
        HStack(spacing: 12) {
            BigStepper(title: "次數", value: $reps)
            BigStepper(title: "組數", value: $sets)
        }
    }

    private var cardioCard: some View {
        VStack(spacing: 14) {
            if HealthWorkouts.isAvailable {
                Button { showingHealthImport = true } label: {
                    Label(healthWorkoutID == nil ? "從 Apple Watch 帶入" : "重新選擇 Apple Watch 紀錄",
                          systemImage: "applewatch")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.field, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            if let healthWorkout {
                Label("已帶入 \(healthWorkout.start.formatted(date: .abbreviated, time: .shortened))，坡度請自己填",
                      systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if healthWorkoutID != nil {
                Label("這筆紀錄是從 Apple Watch 帶入的", systemImage: "applewatch")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            cardioField("坡度", text: $inclineText, unit: "%")
            cardioField("速度", text: $speedText, unit: "km/h")
            cardioField("時間", text: $minutesText, unit: "分")
        }
        .card()
        .sheet(isPresented: $showingHealthImport) {
            HealthImportSheet(onPick: applyHealthWorkout)
        }
    }

    /// 帶入時間、速度、日期；坡度 Apple 不會記錄，保留原本（上次）的數字讓使用者確認
    private func applyHealthWorkout(_ workout: TreadmillWorkout) {
        healthWorkout = workout
        healthWorkoutID = workout.id
        date = workout.start
        minutesText = Units.number(workout.minutes)
        speedText = workout.speedKmh.map(Units.number) ?? ""
        if workout.isRunning && note.isEmpty { note = "跑步" }
    }

    private func cardioField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title).font(.headline).foregroundStyle(.secondary)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.green)
            Text(unit).foregroundStyle(.secondary).frame(width: 48, alignment: .leading)
        }
    }

    private var extrasCard: some View {
        VStack(spacing: 14) {
            if logType != .cardio {
                Toggle(isOn: $isMax) {
                    Text("MAX").font(.headline)
                }
            }
            DatePicker("日期", selection: $date, displayedComponents: .date)
                .font(.headline)
            TextField("備註（例如：一邊、做到沒力）", text: $note, axis: .vertical)
                .padding(12)
                .background(Theme.field, in: .rect(cornerRadius: 14))
        }
        .card()
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(editing == nil ? "記錄" : "儲存修改")
                .font(.title3.bold())
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(Theme.green, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: Logic

    /// 切換 kg/lbs 時把輸入框的數字一併換算
    private var unitBinding: Binding<Bool> {
        Binding {
            useLbs
        } set: { newValue in
            guard newValue != useLbs else { return }
            if let value = parse(weightText) {
                let converted = newValue ? Units.kgToLbs(value) : Units.lbsToKg(value)
                weightText = Units.number(converted)
            }
            useLbs = newValue
        }
    }

    private func adjustWeight(by delta: Double) {
        let value = max(0, (parse(weightText) ?? 0) + delta)
        weightText = Units.number(value)
    }

    private func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func loadInitialValues() {
        guard !loaded else { return }
        loaded = true

        let source = editing ?? exercise.lastEntry
        if let source {
            if let w = source.weightKg { weightText = Units.number(w) }
            if let r = source.reps { reps = r }
            if let s = source.sets { sets = s }
            if let v = source.incline { inclineText = Units.number(v) }
            if let v = source.speed { speedText = Units.number(v) }
            if let v = source.minutes { minutesText = Units.number(v) }
        }
        // 編輯時保留原本的 MAX、備註和日期；新增時這些從空白開始
        if let editing {
            isMax = editing.isMax
            note = editing.note
            date = editing.date
            healthWorkoutID = editing.healthWorkoutID
        }
    }

    private func save() {
        var weightKg = parse(weightText)
        if useLbs, let w = weightKg { weightKg = (Units.lbsToKg(w) * 100).rounded() / 100 }

        let entry = editing ?? WorkoutEntry(date: date, exercise: exercise)
        if editing == nil { context.insert(entry) }

        // 改日期時保留原本的時間；新增時用現在的時間，讓同一天的紀錄依順序排列
        // 從 Apple Watch 帶入時用運動開始的時間
        entry.date = merge(day: date, time: healthWorkout?.start ?? editing?.date ?? .now)
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if logType == .cardio {
            entry.incline = parse(inclineText)
            entry.speed = parse(speedText)
            entry.minutes = parse(minutesText)
            entry.healthWorkoutID = healthWorkoutID
        } else {
            entry.weightKg = weightKg
            entry.reps = reps
            entry.sets = sets
            entry.isMax = isMax
        }
        try? context.save()
        dismiss()
    }

    private func merge(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let t = cal.dateComponents([.hour, .minute, .second], from: time)
        return cal.date(bySettingHour: t.hour ?? 12, minute: t.minute ?? 0, second: t.second ?? 0, of: day) ?? day
    }
}

private struct BigStepper: View {
    var title: String
    @Binding var value: Int

    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            Text(String(value))
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
            HStack(spacing: 10) {
                stepButton("minus") { value = max(1, value - 1) }
                stepButton("plus") { value += 1 }
            }
        }
        .card(padding: 16)
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.field, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

/// 最近 5 筆
private struct RecentEntriesCard: View {
    var exercise: Exercise

    var body: some View {
        let recent = Array(exercise.sortedEntries.prefix(5))
        VStack(alignment: .leading, spacing: 12) {
            Text("最近 5 筆").font(.headline).foregroundStyle(.secondary)
            if recent.isEmpty {
                Text("還沒有紀錄").foregroundStyle(.secondary)
            }
            ForEach(recent) { entry in
                EntryLine(entry: entry)
            }
        }
        .card()
    }
}

/// 一行紀錄：日期、數字、備註
struct EntryLine: View {
    var entry: WorkoutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.date.shortDate)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text(entry.summary)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(entry.isMax ? Theme.orange : .primary)
            }
            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
