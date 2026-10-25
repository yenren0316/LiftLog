import Foundation
import Observation

/// 深層連結實際要去的畫面
enum DeepLinkDestination: Equatable {
    case plan, workout, home
}

extension DeepLink {
    /// 依有沒有進行中的訓練決定去哪裡
    func destination(hasActiveWorkout: Bool) -> DeepLinkDestination {
        switch self {
        case .new: hasActiveWorkout ? .workout : .plan
        case .workout: hasActiveWorkout ? .workout : .home
        }
    }
}

/// 網址（onOpenURL）、控制項和 App Shortcut 的 intent 都把連結交給這裡，由 RootView 依目前狀態導向
@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    /// 等待 RootView 處理的連結
    var pending: DeepLink?

    func open(_ url: URL) {
        if let link = DeepLink(url: url) { pending = link }
    }
}
