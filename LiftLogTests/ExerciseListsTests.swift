import Foundation
import Testing
@testable import LiftLog

@MainActor
struct ExerciseListsTests {
    private let bench = Exercise(name: "臥推", category: .horizontalPush, aliases: ["槓鈴臥推"], equipment: .barbell)
    private let chestMachine = Exercise(name: "胸推訓練機", category: .horizontalPush, equipment: .machine, isArchived: true)
    private let pushUp = Exercise(name: "伏地挺身", category: .horizontalPush, equipment: .bodyweight, logType: .bodyweight)
    private let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)

    private var all: [Exercise] { [bench, chestMachine, pushUp, squat] }

    @Test func librarySearchCoversAllCategoriesButNotArchived() {
        // 動作庫搜尋：直接列出所有分類的結果，不含封存動作
        #expect(Set(ExerciseLists.search(all, query: "").map(\.name)) == ["臥推", "伏地挺身", "深蹲"])
        #expect(ExerciseLists.search(all, query: "胸推").isEmpty)
        #expect(ExerciseLists.search(all, query: "槓鈴").map(\.name) == ["臥推"])   // 比對別名
    }

    @Test func archivedNeverInPicker() {
        let add = ExerciseLists.picker(all, category: nil, excluding: nil, query: "").map(\.name)
        #expect(Set(add) == ["臥推", "伏地挺身", "深蹲"])
        let pushes = ExerciseLists.picker(all, category: .horizontalPush, excluding: bench, query: "").map(\.name)
        #expect(pushes == ["伏地挺身"])
        // 搜尋比對別名
        #expect(ExerciseLists.picker(all, category: nil, excluding: nil, query: "槓鈴").map(\.name) == ["臥推"])
    }

    @Test func untrainedLastInPickerSections() {
        struct Item { var name: String; var last: Date? }
        let items = [Item(name: "前蹲舉", last: nil), Item(name: "深蹲", last: .now), Item(name: "側蹲", last: .distantPast)]
        let pickerOrder = Recency.sortedByNeglect(items, lastDate: \.last, name: \.name, untrainedLast: true).map(\.name)
        #expect(pickerOrder == ["側蹲", "深蹲", "前蹲舉"])
        let defaultOrder = Recency.sortedByNeglect(items, lastDate: \.last, name: \.name).map(\.name)
        #expect(defaultOrder.first == "前蹲舉")
    }
}
