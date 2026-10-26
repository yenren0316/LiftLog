import SwiftUI
import SwiftData

/// 訓練分頁：進行中的訓練或「開始空白訓練」，下面是歷史訓練
struct SessionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var deleteCandidate: WorkoutSession?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScreenHeader(title: "訓練")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))

                Section {
                    if let active = sessions.first(where: \.isActive) {
                        activeCard(active)
                    } else {
                        Button { coordinator.requestStart([], context: context) } label: {
                            Label("開始空白訓練", systemImage: "plus")
                                .font(.title3.bold())
                                .foregroundStyle(Theme.onAccent)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(Theme.accent, in: .capsule)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                let history = sessions.filter { !$0.isActive }
                Section {
                    ForEach(history) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRow(session: session)
                        }
                        .listRowBackground(Theme.card)
                        .swipeActions {
                            Button("刪除", systemImage: "trash", role: .destructive) { deleteCandidate = session }
                        }
                    }
                } header: {
                    Text("歷史訓練（\(history.count)）")
                }
            }
            .listSectionSpacing(12)
            .scrollContentBackground(.hidden)
            .hidesTabBarOnScroll()
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "刪除「\(deleteCandidate?.title ?? "")」？",
                isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }),
                titleVisibility: .visible
            ) {
                Button("刪除整次訓練", role: .destructive) {
                    if let session = deleteCandidate { WorkoutActions.discard(session, in: context) }
                    deleteCandidate = nil
                }
            } message: {
                Text("這次訓練的所有組都會刪除，無法復原。")
            }
        }
    }

    private func activeCard(_ session: WorkoutSession) -> some View {
        Button { coordinator.isExpanded = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label("進行中", systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(session.title.isEmpty ? "空白訓練" : session.title).font(.title3.bold())
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(WorkoutSession.format(duration: timeline.date.timeIntervalSince(session.startedAt)))
                        .font(.title.bold().monospacedDigit())
                }
                Text("點一下繼續").font(.footnote).foregroundStyle(Theme.textSecondary)
            }
            .card()
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.accent.opacity(0.5)))
        }
        .buttonStyle(.pressable)
    }
}

private struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.startedAt.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).weekday(.abbreviated)))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let duration = session.duration {
                    Label(WorkoutSession.format(duration: duration), systemImage: "timer")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Text(session.title.isEmpty ? "訓練" : session.title)
                .font(.body.weight(.semibold))
                .lineLimit(2)
            // 有日型時一起顯示：「ME 下肢・3 個動作」
            Text(([session.dayType?.title].compactMap { $0 } + ["\(session.items.count) 個動作"]).joined(separator: "・"))
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}
