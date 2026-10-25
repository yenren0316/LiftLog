import Foundation
import SwiftData

enum ExerciseMerge {
    /// 來源的名稱與別名併入目標（去重、排除目標本身的名稱）
    nonisolated static func mergedAliases(target: String, targetAliases: [String],
                                          source: String, sourceAliases: [String]) -> [String] {
        var result: [String] = []
        for alias in targetAliases + [source] + sourceAliases
        where alias != target && !result.contains(alias) {
            result.append(alias)
        }
        return result
    }

    /// 紀錄全部移到 target，併入別名後刪除 source。
    /// 同一次訓練裡兩個動作都有時，來源的組接在目標的組後面（同一次訓練同一個動作只出現一次）
    static func merge(_ source: Exercise, into target: Exercise, context: ModelContext) throws {
        precondition(source !== target, "不能合併到自己")
        for item in source.sessionItems {
            if let existing = target.sessionItems.first(where: { $0.session === item.session && $0 !== item }) {
                let offset = (existing.sets.map(\.order).max() ?? -1) + 1
                for set in item.orderedSets {
                    set.order += offset
                    set.sessionExercise = existing
                }
                if !item.note.isEmpty {
                    existing.note = [existing.note, item.note].filter { !$0.isEmpty }.joined(separator: "；")
                }
                context.delete(item)
            } else {
                item.exercise = target
            }
        }
        target.aliases = mergedAliases(target: target.name, targetAliases: target.aliases,
                                       source: source.name, sourceAliases: source.aliases)
        context.delete(source)
        try context.save()
    }
}
