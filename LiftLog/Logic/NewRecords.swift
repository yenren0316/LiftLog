import Foundation

/// 新紀錄（CHANGE_15 §4）：這次訓練中某個動作的估算 1RM（全 App 同一個定義，PersonalRecords.best1RM：Epley，
/// 只算 1～10 下、有重量的已完成正式組和 MAX 組），高於這次訓練開始之前、這個動作所有紀錄最好的估算 1RM。
/// 以前沒有任何可以計算的紀錄時不算；相等不算。估算 1RM 只有重量型的動作有（和動作詳情的個人紀錄一樣）。
/// 完成畫面和訓練摘要頁都呼叫這一個
nonisolated enum NewRecords {
    struct Record: Equatable, Sendable, Identifiable {
        var exerciseID: UUID
        var name: String
        /// 這次最好的估算 1RM（kg）
        var estimated1RM: Double
        /// 這次之前最好的估算 1RM（kg）
        var previous1RM: Double
        var id: UUID { exerciseID }
    }

    /// 這次訓練裡的一個動作：這次的組、這次訓練開始之前這個動作的所有組
    struct Entry: Sendable {
        var exerciseID: UUID
        var name: String
        var logType: LogType = .weight
        var sets: [SetValues]
        var earlier: [SetValues]
    }

    /// 浮點數的誤差以內算相等（相等不算新紀錄）
    static let tolerance = 1e-6

    /// 依 entries 的順序列出刷新紀錄的動作（一次訓練好幾個動作刷新時全部列出）
    static func find(_ entries: [Entry]) -> [Record] {
        entries.compactMap { entry in
            guard entry.logType == .weight,
                  let best = PersonalRecords.best1RM(entry.sets),
                  let before = PersonalRecords.best1RM(entry.earlier),
                  best - before > tolerance
            else { return nil }
            return Record(exerciseID: entry.exerciseID, name: entry.name, estimated1RM: best, previous1RM: before)
        }
    }
}

extension NewRecords {
    /// 這次訓練的新紀錄：每個動作和這次訓練開始之前的紀錄比較（之後的紀錄不算，所以舊的訓練摘要看的是那時候刷新的）
    static func find(in session: WorkoutSession) -> [Record] {
        find(session.orderedItems.compactMap { item in
            guard let exercise = item.exercise else { return nil }
            let earlier = exercise.completedItems
                .filter { $0.session !== session && ($0.session?.startedAt ?? .distantFuture) < session.startedAt }
                .flatMap { $0.completedSets.map(\.values) }
            return Entry(exerciseID: exercise.id, name: exercise.name, logType: exercise.logType,
                         sets: item.completedSets.map(\.values), earlier: earlier)
        })
    }
}
