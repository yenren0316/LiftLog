import Foundation
import Testing
@testable import LiftLog

struct LibraryTests {
    private struct Item {
        var name: String
        var tags: [ExerciseTag] = []
        var equipment: Equipment = .barbell
        var count = 0
    }

    private func order(_ items: [Item]) -> [String] {
        LibraryOrder.sorted(items, tags: \.tags, equipment: \.equipment, count: \.count, name: \.name).map(\.name)
    }

    @Test func fourGroupsInDisplayOrder() {
        let items = [
            Item(name: "滑輪下拉", equipment: .cable, count: 30),
            Item(name: "單手抓舉", tags: [.unilateral, .explosive], equipment: .dumbbell, count: 5),
            Item(name: "後腳抬高蹲", tags: [.unilateral], equipment: .dumbbell, count: 3),
            Item(name: "深蹲", count: 20),
            Item(name: "負重原地起跳", tags: [.explosive], equipment: .kettlebell, count: 1),
            Item(name: "前蹲舉", count: 0),
        ]
        #expect(order(items) == ["深蹲", "前蹲舉", "後腳抬高蹲", "單手抓舉", "負重原地起跳", "滑輪下拉"])
    }

    @Test func explosiveWinsOverUnilateral() {
        #expect(LibraryGroup.of(tags: [.unilateral, .explosive], equipment: .dumbbell) == .explosive)
        #expect(LibraryGroup.of(tags: [], equipment: .cable) == .cable)
        #expect(LibraryGroup.of(tags: [.unilateral], equipment: .cable) == .unilateral)
    }

    @Test func sameGroupSortsByCountThenName() {
        let items = [Item(name: "B", count: 3), Item(name: "A", count: 3), Item(name: "C", count: 9)]
        #expect(order(items) == ["C", "A", "B"])
    }

    @Test func filterIntersection() {
        var filter = LibraryFilter()
        #expect(filter.matches(tags: [], trainingCount: 0))

        filter.trained = .trained
        #expect(filter.matches(tags: [], trainingCount: 2))
        #expect(!filter.matches(tags: [], trainingCount: 0))

        filter.tags = [.unilateral]
        #expect(filter.matches(tags: [.unilateral, .explosive], trainingCount: 2))
        #expect(!filter.matches(tags: [.unilateral], trainingCount: 0))     // 未練過，不符合「練過」
        #expect(!filter.matches(tags: [.explosive], trainingCount: 5))      // 沒有單邊

        filter.trained = .untrained
        filter.tags = [.unilateral, .explosive]
        #expect(filter.matches(tags: [.unilateral, .explosive], trainingCount: 0))
        #expect(!filter.matches(tags: [.unilateral], trainingCount: 0))     // 兩個 tag 都要有
    }
}
