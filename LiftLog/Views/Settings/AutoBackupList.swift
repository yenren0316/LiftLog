import SwiftUI
import SwiftData

/// 資料遷移前自動寫的備份（Documents/AutoBackups）：每一份可以匯出或還原
struct AutoBackupList: View {
    @Environment(\.modelContext) private var context
    @State private var entries: [AutoBackup.Entry] = []
    @State private var restoring: AutoBackup.Entry?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自動備份").font(.headline)
            Text("每次資料遷移前，App 會先把全部資料存一份在這裡。")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            if entries.isEmpty {
                Text("還沒有自動備份").font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
            ForEach(entries) { entry in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title).font(.subheadline.weight(.semibold))
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    ShareLink(item: entry.url) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("匯出")
                    Button("還原") { restoring = entry }
                        .buttonStyle(.pressable)
                        .foregroundStyle(Theme.accent)
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear { entries = AutoBackup.list() }
        .alert("用這份備份取代目前所有資料？", isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } }),
               presenting: restoring) { entry in
            Button("還原", role: .destructive) { restore(entry) }
            Button("取消", role: .cancel) {}
        } message: { entry in
            Text("會回到「\(entry.title)」之前的狀態，之後新增的紀錄會不見。建議先匯出一份目前的資料。")
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") {}
        }
    }

    private func restore(_ entry: AutoBackup.Entry) {
        do {
            try BackupService.restore(BackupFile.decode(Data(contentsOf: entry.url)), into: context)
            message = "還原完成"
        } catch {
            message = "還原失敗：\(error.localizedDescription)"
        }
    }
}
