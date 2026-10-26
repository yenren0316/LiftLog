import SwiftUI

/// 動作的唯讀浮窗：分類、標籤、動作說明和我的筆記。第 3 層（訓練中、編輯訓練）點動作名稱時用，不再 push 頁面
struct ExerciseInfoSheet: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(exercise.name).font(.title2.bold())
                        ForEach(exercise.tags) { Chip(text: $0.title) }
                    }
                    Text("\(exercise.category.fullTitle)・\(exercise.equipment.title)").foregroundStyle(Theme.textSecondary)
                }
                section("核心抗動類型", [exercise.guideCore])
                section("動作要點", exercise.guideCues)
                section("常見錯誤", exercise.guideMistakes)
                if !exercise.myNotes.isEmpty { section("我的筆記", [exercise.myNotes]) }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .screenBackground()
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func section(_ title: String, _ lines: [String]) -> some View {
        let lines = lines.filter { !$0.isEmpty }
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(lines.count > 1 ? "\(index + 1). \(line)" : line)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
