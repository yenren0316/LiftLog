import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_07 C-5：訓練名稱改成訓練目的（T6）
@MainActor
struct SessionTitleTests {
    @Test func purposeByDayType() {
        #expect(SessionTitle.purpose(dayType: .meLower, mainName: "深蹲", categories: [.kneeDominant]) == "下肢最大肌力・深蹲")
        #expect(SessionTitle.purpose(dayType: .meUpper, mainName: "臥推", categories: []) == "上肢最大肌力・臥推")
        #expect(SessionTitle.purpose(dayType: .deLower, mainName: nil, categories: [.hipDominant]) == "下肢速度與爆發")
        #expect(SessionTitle.purpose(dayType: .deUpper, mainName: "爆發划船", categories: []) == "上肢速度與爆發・爆發划船")
    }

    @Test func purposeWithoutDayType() {
        // 依上肢和下肢分類推算，忽略核心、補強、有氧
        #expect(SessionTitle.purpose(dayType: nil, mainName: nil, categories: [.kneeDominant, .core, .cardio]) == "下肢訓練")
        #expect(SessionTitle.purpose(dayType: nil, mainName: nil, categories: [.horizontalPush, .accessory]) == "上肢訓練")
        #expect(SessionTitle.purpose(dayType: nil, mainName: nil, categories: [.hipDominant, .verticalPull]) == "全身訓練")
        #expect(SessionTitle.purpose(dayType: nil, mainName: nil, categories: [.cardio]) == "有氧")
        #expect(SessionTitle.purpose(dayType: nil, mainName: nil, categories: []) == "訓練")
        #expect(SessionTitle.purpose(dayType: nil, mainName: nil, categories: [.core, .accessory]) == "訓練")
    }

    @Test func legacyAutomaticDetection() {
        let names: Set<String> = ["臥推", "滑輪下拉", "跑步機", "坐姿 Cable 划船", "槓鈴臥推"]
        #expect(SessionTitle.isLegacyAutomatic("", exerciseNames: names))
        #expect(SessionTitle.isLegacyAutomatic("臥推", exerciseNames: names))
        #expect(SessionTitle.isLegacyAutomatic("臥推＋滑輪下拉＋跑步機", exerciseNames: names))
        #expect(SessionTitle.isLegacyAutomatic("臥推＋坐姿 Cable 划船 等 4 項", exerciseNames: names))
        #expect(SessionTitle.isLegacyAutomatic("槓鈴臥推＋跑步機", exerciseNames: names))   // 別名也算
        #expect(!SessionTitle.isLegacyAutomatic("推日", exerciseNames: names))
        #expect(!SessionTitle.isLegacyAutomatic("臥推＋教練課", exerciseNames: names))     // 有一段不是動作名稱
        #expect(!SessionTitle.isLegacyAutomatic("拉＋有氧", exerciseNames: names))
    }

    @Test func migrationRegeneratesAutomaticAndKeepsCustomTitles() throws {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let squat = Exercise(name: "深蹲", category: .kneeDominant, tags: [.main], aliases: ["背蹲舉"], equipment: .barbell)
        let bench = Exercise(name: "臥推", category: .horizontalPush, tags: [.main], equipment: .barbell)
        [squat, bench].forEach(context.insert)
        func session(_ title: String, _ exercises: [Exercise], roles: [Role]? = nil, dayType: DayType? = nil, day: Int) -> WorkoutSession {
            let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 19))!
            let s = WorkoutSession(startedAt: date, endedAt: date, title: title, dayType: dayType)
            context.insert(s)
            for (i, e) in exercises.enumerated() {
                context.insert(SessionExercise(session: s, exercise: e, order: i, role: roles?[i]))
            }
            return s
        }
        let auto = session("深蹲＋臥推", [squat, bench], day: 1)
        let alias = session("背蹲舉", [squat], roles: [.maxEffort], dayType: .meLower, day: 2)
        let custom = session("腿日", [squat], day: 3)
        let empty = session("", [bench], day: 4)
        let result = try AutoTitles.apply(in: context)
        #expect(result.regenerated == 3)
        #expect(result.custom.map(\.title) == ["腿日"])
        #expect(auto.title == "全身訓練" && !auto.isTitleCustom)
        #expect(alias.title == "下肢最大肌力・深蹲")
        #expect(empty.title == "上肢訓練")
        #expect(custom.title == "腿日" && custom.isTitleCustom)
        // 自訂的名稱之後動作改變也不覆蓋
        _ = WorkoutActions.add(bench, to: custom, in: context)
        #expect(custom.title == "腿日")
    }

    @Test func restoringAnOldBackupKeepsCustomTitles() throws {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let id = UUID()
        let json = """
        {"version":5,
         "exercises":[{"id":"\(id.uuidString)","name":"臥推","category":"horizontalPush","tags":[],"aliases":[],
                       "englishName":"","equipment":"barbell","logType":"weight","note":"","isArchived":false}],
         "sessions":[{"id":"\(UUID().uuidString)","startedAt":"2026-06-24T12:00:00+08:00","endedAt":"2026-06-24T13:00:00+08:00",
                      "title":"推日","note":"","hasTime":true,"items":[]},
                     {"id":"\(UUID().uuidString)","startedAt":"2026-06-25T12:00:00+08:00","endedAt":"2026-06-25T13:00:00+08:00",
                      "title":"臥推","note":"","hasTime":true,"items":[]}],
         "bodyWeights":[]}
        """
        try BackupService.restore(BackupFile.decode(Data(json.utf8)), into: context)
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt)]))
        #expect(sessions.map(\.isTitleCustom) == [true, false])
    }
}
