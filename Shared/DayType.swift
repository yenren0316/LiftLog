import Foundation

/// 共軛訓練的日型（App 和小工具共用）。依 ME 下肢 → ME 上肢 → DE 下肢 → DE 上肢 輪流
nonisolated enum DayType: String, Codable, CaseIterable, Identifiable, Sendable {
    case meLower, meUpper, deLower, deUpper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meLower: "ME 下肢"
        case .meUpper: "ME 上肢"
        case .deLower: "DE 下肢"
        case .deUpper: "DE 上肢"
        }
    }

    /// ME（最大肌力）日；否則是 DE（速度）日
    var isMaxEffort: Bool { self == .meLower || self == .meUpper }
    var isLower: Bool { self == .meLower || self == .deLower }

    /// 輪替的下一個日型
    var next: DayType {
        switch self {
        case .meLower: .meUpper
        case .meUpper: .deLower
        case .deLower: .deUpper
        case .deUpper: .meLower
        }
    }
}
