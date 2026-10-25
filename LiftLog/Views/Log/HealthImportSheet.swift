import SwiftUI
import SwiftData

/// 列出最近 7 天 Apple Watch／健身 App 的室內步行與跑步，已帶入過的不顯示
struct HealthImportSheet: View {
    var onPick: (TreadmillWorkout) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<SetRecord> { $0.healthWorkoutID != nil })
    private var importedSets: [SetRecord]

    @State private var workouts: [TreadmillWorkout] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                let imported = Set(importedSets.compactMap(\.healthWorkoutID))
                let available = workouts.filter { !imported.contains($0.id) }

                if loading {
                    ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).listRowBackground(Theme.card)
                } else if available.isEmpty {
                    Text(emptyMessage(hasImportedAll: !workouts.isEmpty))
                        .foregroundStyle(.secondary)
                        .listRowBackground(Theme.card)
                }

                ForEach(available) { workout in
                    Button {
                        onPick(workout)
                        dismiss()
                    } label: {
                        WorkoutRow(workout: workout)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Apple Watch 紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .task(load)
        }
    }

    private func emptyMessage(hasImportedAll: Bool) -> String {
        if hasImportedAll { return "最近 7 天的紀錄都已經帶入過了。" }
        return """
        最近 7 天沒有找到室內步行或室內跑步。

        如果確定有記錄，請到「設定 → 健康 → 資料存取與裝置 → LiftLog」確認已允許讀取「體能訓練」。
        """
    }

    private func load() async {
        defer { loading = false }
        do {
            try await HealthWorkouts.requestAuthorization()
            workouts = try await HealthWorkouts.recentIndoorWalksAndRuns()
        } catch {
            errorMessage = "讀不到健康資料：\(error.localizedDescription)"
        }
    }
}

private struct WorkoutRow: View {
    var workout: TreadmillWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.isRunning ? "室內跑步" : "室內步行").font(.headline)
                Spacer()
                Text(workout.start.formatted(.dateTime.month().day().weekday().hour().minute()))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Text("\(Units.number(workout.minutes)) 分")
                if let km = workout.distanceKm {
                    Text("\(km.formatted(.number.precision(.fractionLength(2)))) km")
                }
                if let speed = workout.speedKmh {
                    Text("\(Units.number(speed)) km/h")
                }
            }
            .font(.body.weight(.semibold).monospacedDigit())
            .foregroundStyle(Theme.green)
            Text(workout.source).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
