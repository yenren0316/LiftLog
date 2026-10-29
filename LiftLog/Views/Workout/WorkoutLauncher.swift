import SwiftUI
import SwiftData

/// 開始訓練的唯一入口（CHANGE_07 A-2）：依建立菜單開始、自由選動作、再做一次、補登都走這裡。
/// 有進行中的訓練時：
/// - 進入建立菜單前先問「繼續目前訓練／建立新菜單」，這時還不結束目前的訓練
/// - 真的要開始時才確認「將結束目前的訓練，未完成的組會刪除」（launchConfirmation，全 App 只有這一份）
/// - 中途取消，原本的訓練完全不受影響
/// 補登是已結束的訓練，不和進行中的訓練衝突
@Observable
final class WorkoutLauncher {
    /// 確認對話框要從哪個畫面出現：sheet 開著時，對話框要掛在最上層的畫面
    enum Origin {
        case root, plan
    }

    struct Request {
        var exercises: [Exercise] = []
        var roles: [Role]?
        var dayType: DayType?
        /// 開始後直接打開「新增動作」（自由選動作）
        var openAdd = false
        /// 補登：這次訓練的開始和結束時間
        var backfill: DateInterval?
        var origin: Origin = .root

        /// 建立菜單的「開始訓練」：依格子的順序，每個動作的角色就是格子的角色；一個動作都沒有時為 nil
        static func plan(_ selection: [(exerciseID: UUID, role: Role)], exercises: [Exercise], dayType: DayType,
                         backfill: DateInterval?) -> Request? {
            let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let chosen = selection.compactMap { pick in byID[pick.exerciseID].map { ($0, pick.role) } }
            guard !chosen.isEmpty else { return nil }
            return Request(exercises: chosen.map(\.0), roles: chosen.map(\.1), dayType: dayType, backfill: backfill, origin: .plan)
        }
    }

    /// 建立菜單的 sheet（RootView 呈現）
    var planRequest: PlanRequest?
    /// 有進行中的訓練時，進入建立菜單前的詢問
    var planWithActive: PlanRequest?
    /// 等待確認「將結束目前的訓練」
    var pendingStart: Request?

    let coordinator: WorkoutCoordinator
    @ObservationIgnored private let restTimer: RestTimer
    /// sheet 關掉之後要做的事（展開訓練中畫面、打開補登的訓練）
    @ObservationIgnored private var afterDismiss: (() -> Void)?

    init(coordinator: WorkoutCoordinator, restTimer: RestTimer = .shared) {
        self.coordinator = coordinator
        self.restTimer = restTimer
    }

    // MARK: - 建立菜單

    /// 「下一次」卡、深層連結 liftlog://new、小工具的＋、控制項和 Siri 都從這裡進入建立菜單
    func requestPlan(_ answers: PlanAnswers? = nil, backfill: DateInterval? = nil, context: ModelContext) {
        let request = PlanRequest(answers: answers, backfill: backfill)
        if backfill == nil, WorkoutActions.activeSession(in: context) != nil {
            planWithActive = request
        } else {
            planRequest = request
        }
    }

    func continueCurrent() {
        planWithActive = nil
        coordinator.isExpanded = true
    }

    /// 選「建立新菜單」：打開建立菜單，目前的訓練還不結束
    func openPlanKeepingCurrent() {
        planRequest = planWithActive
        planWithActive = nil
    }

    // MARK: - 開始

    /// 有進行中的訓練（而且不是補登）時先等確認，回傳 nil
    @discardableResult
    func start(_ request: Request, context: ModelContext) -> WorkoutSession? {
        if request.backfill == nil, WorkoutActions.activeSession(in: context) != nil {
            pendingStart = request
            return nil
        }
        return perform(request, context: context)
    }

    @discardableResult
    func confirmPendingStart(context: ModelContext) -> WorkoutSession? {
        guard let request = pendingStart else { return nil }
        pendingStart = nil
        finishActive(context: context)
        return perform(request, context: context)
    }

    func cancelPendingStart() {
        pendingStart = nil
    }

    /// 「再做一次」：同樣的動作、順序、角色與日型；CHANGE_04 的舊角色改用動作的預設角色
    func repeatSession(_ session: WorkoutSession, origin: Origin, context: ModelContext) {
        let items = session.orderedItems.filter { $0.exercise != nil }
        let roles = items.map { $0.role.isLegacy ? $0.exercise!.defaultRole : $0.role }
        start(Request(exercises: items.compactMap(\.exercise), roles: roles, dayType: session.dayType, origin: origin),
              context: context)
    }

    /// RootView 的 sheet（建立菜單、訓練狀態）關掉之後要做的事
    func afterSheetDismiss(_ action: @escaping () -> Void) {
        afterDismiss = action
    }

    /// RootView 的 sheet 關掉時呼叫
    func sheetDismissed() {
        let action = afterDismiss
        afterDismiss = nil
        action?()
    }

    /// 為了開始新的訓練而結束目前的訓練：刪掉未完成的組，休息倒數一起停掉（不然會延續到新訓練）
    private func finishActive(context: ModelContext) {
        restTimer.skip()
        if let session = WorkoutActions.activeSession(in: context) {
            WorkoutActions.finish(session, choice: .deleteIncomplete, in: context)
        }
    }

    private func perform(_ request: Request, context: ModelContext) -> WorkoutSession {
        let session = WorkoutActions.start(with: request.exercises, roles: request.roles, dayType: request.dayType,
                                           backfill: request.backfill, in: context)
        let show: () -> Void
        if request.backfill != nil {
            // 補登：切到歷程、推入這次訓練的摘要頁，直接進入編輯畫面（摘要頁上的全螢幕編輯）
            show = { [coordinator] in coordinator.showSummary(of: session, editing: true, openAdd: request.openAdd) }
        } else {
            show = { [coordinator] in
                coordinator.openAddOnExpand = request.openAdd
                coordinator.isExpanded = true
            }
        }
        switch request.origin {
        case .root:
            show()
        case .plan:
            afterDismiss = show
            planRequest = nil
        }
        return session
    }
}

extension View {
    /// 「將結束目前的訓練，未完成的組會刪除」：全 App 唯一的開始衝突對話框，掛在發出請求的畫面上
    func launchConfirmation(_ launcher: WorkoutLauncher, origin: WorkoutLauncher.Origin, context: ModelContext) -> some View {
        alert(
            "將結束目前的訓練，未完成的組會刪除",
            isPresented: Binding(get: { launcher.pendingStart?.origin == origin },
                                 set: { if !$0 { launcher.cancelPendingStart() } })
        ) {
            Button("結束並開始新的訓練", role: .destructive) { launcher.confirmPendingStart(context: context) }
            Button("取消", role: .cancel) { launcher.cancelPendingStart() }
        }
    }

    /// 有進行中的訓練時進入建立菜單：「繼續目前訓練」或「建立新菜單」（選建立新菜單時還不結束目前的訓練）
    func planEntryQuestion(_ launcher: WorkoutLauncher) -> some View {
        alert(
            "已經有進行中的訓練",
            isPresented: Binding(get: { launcher.planWithActive != nil }, set: { if !$0 { launcher.planWithActive = nil } })
        ) {
            Button("繼續目前訓練") { launcher.continueCurrent() }
            Button("建立新菜單") { launcher.openPlanKeepingCurrent() }
            Button("取消", role: .cancel) { launcher.planWithActive = nil }
        } message: {
            Text("建立新菜單時，要到按下「開始訓練」才會結束目前的訓練。")
        }
    }
}
