import Foundation

/// 一次訓練練的部位（App 和小工具共用；依動作推算部位的 infer 在 App 的 Roles.swift）
nonisolated enum Region: String, Codable, CaseIterable, Identifiable, Sendable {
    case upper, lower, full, unspecified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upper: "上半身"
        case .lower: "下半身"
        case .full: "全身"
        case .unspecified: "未指定"
        }
    }
}
