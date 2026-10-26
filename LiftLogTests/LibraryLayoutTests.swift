import Foundation
import Testing
@testable import LiftLog

/// 使用中的動作、分類與標籤：CHANGE_06 的動作庫 v2（51 個重訓動作＋跑步機）
@MainActor
struct LibraryLayoutTests {
    private static let expected: [(ExerciseCategory, [(String, [ExerciseTag])])] = [
        (.kneeDominant, [("深蹲", [.main]), ("前蹲舉", [.main]), ("後腳抬高蹲", [.unilateral]), ("高背槓分腿蹲", [.unilateral]),
                         ("側蹲", [.unilateral]), ("負重原地起跳", [.explosive])]),
        (.hipDominant, [("傳統硬舉", [.main]), ("六角槓硬舉", [.main]), ("相撲硬舉", [.main]), ("槓鈴早安式", [.main]),
                        ("羅馬尼亞式硬舉", []), ("單腳 RDL", [.unilateral]), ("臀推", []), ("壺鈴擺盪", [.explosive]),
                        ("單手抓舉", [.unilateral, .explosive])]),
        (.horizontalPush, [("臥推", [.main]), ("上斜臥推", [.main]), ("地板臥推", [.main]), ("窄握臥推", [.main]),
                           ("啞鈴臥推", []), ("啞鈴上斜臥推", []), ("地板啞鈴臥推", [])]),
        (.horizontalPull, [("爆發划船", [.explosive]), ("反式划船", []), ("坐姿 Cable 划船", []), ("槓鈴俯身划船", []),
                           ("單手啞鈴划船", [.unilateral]), ("胸靠上斜椅啞鈴划船", [])]),
        (.verticalPush, [("肩推", [.main]), ("坐姿槓鈴肩推", [.main]), ("坐姿啞鈴肩推", []), ("雙槓撐", []),
                         ("借力推舉", [.explosive])]),
        (.verticalPull, [("輔助引體向上", []), ("滑輪下拉", [])]),
        (.core, [("腹前推", []), ("地雷管抗旋轉", []), ("坐姿分腿壺鈴三點搬移", []), ("六角槓原地踏步", []),
                 ("仰臥拉舉", []), ("單手啞鈴臥推", [.unilateral]), ("棒式划船", []), ("窄跪姿單手啞鈴肩推", [.unilateral]),
                 ("單手壺鈴擺盪", [.unilateral, .explosive]), ("行李箱原地踏步", [.unilateral])]),
        (.accessory, [("三頭肌滑輪下拉", []), ("二頭彎舉", []), ("面拉", []), ("YTW", []), ("仰臥啞鈴三頭伸展", []),
                      ("JM 推", [])]),
        (.cardio, [("跑步機", [])]),
    ]

    private func seed() throws -> BackupFile {
        let url = try #require(Bundle.main.url(forResource: "seed", withExtension: "json"))
        return try BackupFile.decode(Data(contentsOf: url))
    }

    @Test func activeExercisesMatchTheList() throws {
        let active = try seed().exercises.filter { !$0.isArchived }
        #expect(active.count == 52)
        #expect(Self.expected.flatMap(\.1).count == 52)
        // 和啟動時套用的 ConjugateLibrary 一致
        #expect(Set(ConjugateLibrary.entries.map(\.name)) == Set(active.map(\.name)))
        let actual = Dictionary(uniqueKeysWithValues: active.map { ($0.name, $0) })
        for (category, list) in Self.expected {
            for (name, tags) in list {
                let record = try #require(actual[name], "\(name)")
                #expect(record.category == category.rawValue, "\(name)")
                #expect(record.tags == tags.map(\.rawValue), "\(name)")
            }
        }
    }

    @Test func archivedExercisesUseTheNewCategories() throws {
        let archived = Dictionary(uniqueKeysWithValues: try seed().exercises.filter(\.isArchived).map { ($0.name, $0.category) })
        let expected: [String: ExerciseCategory] = [
            "腿推機": .kneeDominant, "深蹲訓練機": .kneeDominant, "超級深蹲訓練架": .kneeDominant, "腿部伸張機": .kneeDominant,
            "臥姿腿彎舉機": .hipDominant, "彈力繩壺鈴擺盪": .hipDominant, "拋沙包": .hipDominant,
            "胸推訓練機": .horizontalPush, "滾木槓臥推": .horizontalPush, "背部訓練機": .horizontalPull,
            "肩推機": .verticalPush, "背部下拉訓練機": .verticalPull,
            "腹肌滾輪": .core, "單手硬舉原地踏步": .core, "單邊地雷管划船": .core, "垂直舉肩訓練機": .accessory,
        ]
        #expect(archived == expected.mapValues(\.rawValue))
    }

    @Test func renamesKeepOldNamesAsAliases() throws {
        let byName = Dictionary(uniqueKeysWithValues: try seed().exercises.map { ($0.name, $0) })
        #expect(byName["深蹲"]?.aliases == ["背蹲舉", "高背深蹲", "槓鈴深蹲"])
        #expect(byName["負重原地起跳"]?.aliases.contains("壺鈴原地起跳") == true)
        #expect(byName["六角槓原地踏步"]?.aliases.contains("六角槓階梯上下") == true)
        #expect(byName["六角槓階梯上下"] == nil)
    }

    @Test func legacyCategoriesBecomeCore() {
        #expect(ExerciseCategory(stored: "rotation") == .core)
        #expect(ExerciseCategory(stored: "loadedCarry") == .core)
        #expect(ExerciseCategory(stored: "unusualPosture") == .core)
        #expect(ExerciseCategory(stored: "hipDominant") == .hipDominant)
        #expect(ExerciseCategory.allCases.count == 9)
    }
}
