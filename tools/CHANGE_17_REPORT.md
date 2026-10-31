# CHANGE_17 鎖定畫面的按鈕仍然要求解鎖：根本原因調查報告

- 日期：2026-11-01
- 範圍：
  - §0：存原文；CHANGE_16 標成未收斂（STATUS 最上面、CHANGE_16 報告第 2 節的註記）。
  - §2-1：靜態檢查。
  - §2-2：DEBUG 診斷紀錄。
  - §2-3：實機重現一次，收集診斷紀錄和手機的系統日誌。
  - **§3 依規格「先停下來」**：原因在 iOS 本身，App 的程式沒有被呼叫，也沒有公開的 API 可以改變（第 2、5 節）。所以 §3 沒有修改任何行為，D1～D3 沒有驗證，等使用者決定替代做法。
- 結果摘要：
  - **按下按鈕後，`perform` 完全沒有被執行。**
  - 要求解鎖的是 iOS 負責執行即時動態按鈕的系統程序：chronod 叫起的 `BackgroundShortcutRunner`（WorkflowKit）。它在聯絡 App 之前，就先向 SpringBoard 要求解鎖；使用者取消後，這個動作以錯誤結束。
  - App 對這個 intent 的宣告系統都收到了：
    - 「完成這組」明確宣告 `alwaysAllowed`。
    - 只在背景執行，不打開 App。
  - 但手機上 iOS 27.2 的 chronod 對這次互動套用了「裝置鎖定時要驗證」的互動政策，把 App 的宣告蓋掉了。
- 驗證環境：
  - Xcode 27.2（27B52，iphoneos27.2 SDK）。
  - 實機：iPhone 17，**iOS 27.2（24B119）**，有密碼；裝的是加了診斷紀錄的 Debug 版，覆蓋安裝、沒有刪除 App。
  - 模擬器：iPhone 17 Pro（iOS 26.5），測試一律 `-parallel-testing-enabled NO`。
  - 參考用的系統框架：Xcode 的 iOS DeviceSupport 裡手機 27.2 的系統函式庫，以及 iOS 27.1 模擬器 runtime。
- 文件：
  - `tools/changes/CHANGE_17.md`（原文）
  - `tools/changes/README.md`
  - `tools/STATUS.md`（最上面的註記、進度表）
  - `tools/CHANGE_16_REPORT.md`（第 2 節的粗體註記）
  - `SPEC.md`（開頭摘要；11-5 即時動態按鈕「不用解鎖」的註記；13 開發用參數）
  - 這份報告
- 隱私：診斷紀錄、系統日誌、實驗輸出都只在 `tools/fixtures/change17/`（已在 .gitignore），沒有 commit。以下引用的日誌已經去掉裝置名稱、UDID、Team ID 和本機路徑；時間是這次測試的時間，不是訓練紀錄。

---

## 1. 根本原因

### 1-1. 結論
1. **perform 沒有被執行。**
   - App 的程序和小工具擴充都沒有寫下任何一筆「開始」。
   - App 的程序在按下的前後一直在背景，系統從頭到尾沒有呼叫它。
2. **要求解鎖的是 iOS，不是 App 的程式。** 系統執行即時動態按鈕的流程是：
   - WidgetRenderer_Activities（畫即時動態的程序）收到點擊。
   - chronod 叫起 `BackgroundShortcutRunner`（WorkflowKit，`runSource: widgetkit`）。
   - runner 在聯絡 App 之前呼叫 `requestUnlockIfNeeded:`，向 SpringBoard（`SBSLockScreenService`）要求解鎖，畫面出現密碼。
   - 取消後，動作以 `WFActionErrorDomain` code 17 結束。
3. **App 的宣告系統有收到，但被蓋掉了。**
   - 系統讀到的 metadata 是：「完成這組」明確指定 `alwaysAllowed`（`isAuthPolExplicit: true`）、`openAppWhenRun: false`、`supportedModes: 1`（只在背景）。
   - 小工具送出的 LNAction 也帶著 `explicitAuthenticationPolicy: 0`，也就是明確的 alwaysAllowed。
   - 照 runner 的規則（1-3 第 1 點），這樣的 metadata 不會要求解鎖。所以要求解鎖的指示一定來自呼叫它的 chronod，也就是「這次互動要驗證」。
4. **手機的 iOS 27.2 會把即時動態的互動標成「鎖定時要驗證」。**
   - 手機 27.2 的 ChronoCore（chronod 的主體）依互動的 `InteractionAuthenticationPolicy` 決定傳給 runner 的值。有三種：
     - `requiresAuthenticationIfKeybagLocked`（鎖定時要驗證）
     - `followsActionDefinedPolicyIfExplicitlySet`（照 intent 明確指定的）
     - `alwaysAllowed`
   - 27.2 的這段程式有把值設成「要驗證」的分支；iOS 27.1 模擬器裡同一個函式只會給「照 metadata」或「不用驗證」。
   - 這個互動政策由系統的即時動態畫面（WidgetRenderer 的 `handleInteraction(_:authenticationPolicy:action:)`、`keybagLockPolicy`）決定。iOS 27.2 SDK 的 AppIntents、WidgetKit、ActivityKit、SwiftUI 都沒有可以設定它的公開 API。
5. 模擬器測不到：
   - 模擬器沒有密碼，裝置不會「鎖定」，就算要求解鎖也會直接通過。
   - CHANGE_16 的 UI 測試用的是 iOS 26.5 模擬器，runner 直接進入 SessionKit、叫起 App 執行（1-2 的對照）。

**還不知道的事**：什麼條件讓系統對 LiftLog 的即時動態選了「鎖定時要驗證」。可能是：
- iOS 27.2 對所有第三方即時動態按鈕都這樣；
- 和某個條件有關，例如免費開發者帳號、開發版簽署。

日誌裡相關的值都是 `<private>`；系統程序在 SIP 下也不能用 lldb 掛上去，沒辦法再往下確認。不管是哪一種，App 這邊都沒有可以改的設定或 API。這符合規格「iOS 本身的限制，先停下來」的條件（第 5 節）。

### 1-2. 證據：診斷紀錄（手機，`tools/fixtures/change17/intent-log_repro1.jsonl`）
這是安裝後到重現結束的全部紀錄，只有兩筆，都是 App 啟動：

```
2026-11-01T00:30:59.344+0800  App 啟動・啟動  process=com.aaronhou.LiftLog   ← 安裝後
2026-11-01T00:35:16.529+0800  App 啟動・啟動  process=com.aaronhou.LiftLog   ← 使用者打開 App 開始測試訓練
（00:35:49、00:36:11 按了兩次「完成這組」：沒有任何一筆「開始」，App 和小工具擴充都沒有）
```

模擬器上同樣的按鈕（UI 測試按真的即時動態，00:36～00:38）。這是對照組，App 的程序在背景執行並且成功：
```
00:36:51.171 完成這組・開始 protectedData=true appState=background … 即時動態允許・1 個 ["active"]；沒有在休息
00:36:51.588 完成這組・成功 protectedData=true appState=background completed；… 休息到 00:38:21
```

### 1-3. 證據：手機的系統日誌（`tools/fixtures/change17/repro1.logarchive`，摘錄）
第一次按下「完成這組」（第二次 00:36:11 完全相同）：

```
00:35:49.438 WidgetRenderer_Activities  [chrono:activityRendererClient] Handle action: <LNAction identifier: CompleteSetIntent,
             mangledTypeName: 23LiftLogWidgetsExtension17CompleteSetIntentV, openAppWhenRun: NO,
             systemProtocols: SessionStartingAction, parameters: (setID <redacted>), explicitAuthenticationPolicy: 0>
00:35:49.613 BackgroundShortcutRunner   Starting shortcut run: <WFWorkflow name: 完成這組, actions: 1>,
             request: <WFContextualActionRunRequest runSource: widgetkit, presentationMode: None …>
00:35:49.601 BackgroundShortcutRunner   [appprotection] hidden: <private>, locked: <private> effectivelyLocked: <private>
00:35:49.618 BackgroundShortcutRunner   Action <WFLinkAction com.aaronhou.LiftLog.CompleteSetIntent> finished processing parameter states.
00:35:49.621 BackgroundShortcutRunner   #LSApplicationRestrictionsManager lazy-loading for restricted bundleIDs got <private>
00:35:50.131 sharingd                   System UI Changed 0x802 < LS Passcode >          ← 密碼畫面出現（按下後 0.7 秒）
00:35:50.133 cameracaptured             … foreground:[com.apple.springboard.passcode]
00:35:59.653 BackgroundShortcutRunner   F Action timed out, and did not report whether or not it wants progress in 10.000000 …
00:35:59.868 BackgroundShortcutRunner   E SBSLockScreenService: error from request for unlock : Error Domain=NSPOSIXErrorDomain Code=16
00:35:59.874 BackgroundShortcutRunner   E Action <WFLinkAction com.aaronhou.LiftLog.CompleteSetIntent> finished with error
             {domain: WFActionErrorDomain, code: 17}
```

- 同一段時間 LiftLog 的程序（`running-active-NotVisible` → 00:35:58 `Suspending task`）只有 RunningBoard 的狀態更新，沒有任何 App Intents 的連線，也沒有診斷紀錄的 `LiftLogDiag` 開始。
- linkd 在 00:30:59 已經把 App 和小工具兩份 metadata 都建好索引（`Adding …/LiftLog.app/Metadata.appintents/extract.actionsdata`、`…/LiftLogWidgetsExtension.appex/…`、`combining 2 sources`），不是缺 metadata。

模擬器（iOS 26.5）的同一段對照：處理完參數之後沒有要求解鎖，直接取得 SessionKit 的 assertion、叫起 App 執行：
```
00:36:50.973 BackgroundShortcutRunner  -[WFAction takeSessionKitAssertionIfNeededWithError:] Action says it's going to take assertion itself...
00:36:50.978 BackgroundShortcutRunner  Attempting to take SessionKit assertion for com.aaronhou.LiftLog...
00:36:50.993 BackgroundShortcutRunner  [FBSSystemService] Sending request to open "com.aaronhou.LiftLog" with action(s): <UILinkConnectionAction>
00:36:51.692 BackgroundShortcutRunner  Action <WFLinkAction com.aaronhou.LiftLog.CompleteSetIntent> finished with output of 0
```

### 1-4. 證據：系統框架的判斷規則（只讀，沒有修改任何東西）
日誌只說了「要求解鎖」，沒有說原因，所以我讀了系統框架的程式碼：
- 手機 27.2 的版本：Xcode 連接手機時存在 `iOS DeviceSupport/… 27.2 (24B119)` 的系統函式庫。
- iOS 27.1 模擬器 runtime。

1. **WorkflowKit**：`-[WFAppIntentExecutionAction requiresUnlock]`（`WFLinkAction` 的父類別，手機 27.2 和 27.1 相同）。依序判斷：
   - ToolKit 呼叫的 → 不用解鎖。
   - 呼叫方指定 1 → **要解鎖**；指定 2 → 不用。
   - 其他情況看 metadata：0（alwaysAllowed）→ 不用；2 → 要；1 → 要（除非請求來自別的裝置）。
   - `checkUserInterfaceAndRun` 在執行前呼叫 `requestUnlockIfNeeded:`，只有 `requiresUnlock` 是 YES 才向 SpringBoard 要求解鎖。
   - LiftLog 的 metadata 是 0，所以 YES 只可能來自呼叫方指定 1。
2. **runner 的呼叫方**：VoiceShortcutClient `WFLinkActionWorkflowRunnerClient initWithLinkAction:…authenticationPolicy:` 把 chronod 給的值照抄（1→1、2→2、其他→0），WorkflowKit 再照抄給 action。
3. **chronod（ChronoCore）**：即時動態的互動（`ActivityInteraction`、`Handle interaction`）走一個共用函式，依互動的政策算出要傳的值。
   - iOS 27.1 模擬器：只有 2（相機擷取的 intent）或 0（照 metadata）。
   - **手機 27.2**：同一個函式多了把值設成 1 的分支（互動政策的某一個 case），以及把一個布林值直接當成值的分支。
   - `InteractionAuthenticationPolicy` 的三個 case 名稱見 1-1 第 4 點。
4. **LinkMetadata**：metadata 的 `authenticationPolicy` 是「明確指定的值，沒有就 0」。LNAction 的描述用 `%@` 印 `explicitAuthenticationPolicy`，所以日誌裡的 `0` 是明確的 alwaysAllowed（沒有值會印 `(null)`）。
5. 用實驗建置確認 App Intents metadata 的編號（在暫存的 worktree，沒有 commit）：

   | 宣告 | metadata 的值 | `isAuthPolExplicit` |
   |---|---|---|
   | 預設 | 0 | false |
   | `.alwaysAllowed` | 0 | true |
   | `.requiresAuthentication` | 1 | true |
   | `.requiresLocalDeviceAuthentication` | 2 | true |

6. iOS 27.2 SDK 的 AppIntents、WidgetKit、ActivityKit、SwiftUI 都沒有可以設定即時動態互動驗證政策的公開 API。ActivityKit 的 `Activity.request` 只有 `pushType`、`style`、`alertConfiguration`、`start`。

---

## 2. 2-1 靜態檢查（逐項）

### 2-1-1. 即時動態上的按鈕
| 按鈕 | 寫法 | 有沒有被 Link／widgetURL 蓋住 |
|---|---|---|
| 完成這組 | `Button(intent: CompleteSetIntent(setID:))`，`.buttonStyle(.borderedProminent)`（`Shared/WorkoutActivityViews.swift` `completeButton`） | 沒有 `Link`（小工具和即時動態的程式裡沒有 SwiftUI `Link`）。整個即時動態有 `.widgetURL(liftlog://workout)`（鎖定畫面和動態島各一個，`LiftLogWidgets/WorkoutLiveActivity.swift`），只用在按鈕以外的地方。日誌證實按下的是按鈕：`Handle action: <LNAction … CompleteSetIntent>`，不是打開網址。 |
| 跳過休息 | `Button(intent: SkipRestIntent())`，`.bordered` | 同上 |
| +15 秒 | `Button(intent: ExtendRestIntent())`，`.bordered` | 同上 |
| （打開 App 填寫、全部完成） | 文字，不是按鈕；點即時動態本身走 `widgetURL` | — |

### 2-1-2. intent
metadata 是實際裝到手機那一版（`Metadata.appintents/extract.actionsdata`），App 和小工具兩份內容相同：

| intent | 遵循的 protocol | openAppWhenRun | supportedModes | authenticationPolicy | perform 的回傳 | target |
|---|---|---|---|---|---|---|
| 完成這組 `CompleteSetIntent` | `LiveActivityIntent`（metadata 的 systemProtocol 是 `SessionStarting`）；沒有 `ForegroundContinuableIntent`、`OpenIntent`、`AudioPlaybackIntent` | false | 1（只在背景） | 0＝alwaysAllowed，**明確指定**（`isAuthPolExplicit: true`） | `.result()`，沒有 `opensIntent`，也沒有任何要求打開 App 的回傳 | App 和小工具都有（`Shared/WorkoutIntents.swift`）。App 的 perform 是真的動作（`LiftLog/Intents/WorkoutIntents+App.swift`），小工具的是空的（`LiftLogWidgets/WorkoutIntents+Widget.swift`） |
| 跳過休息 `SkipRestIntent` | 同上 | false | 1 | 0，**沒有明確指定**（預設） | `.result()` | 同上 |
| +15 秒 `ExtendRestIntent` | 同上 | false | 1 | 0，沒有明確指定 | `.result()` | 同上 |
| （參考）開始訓練 `StartWorkoutIntent` | `AppIntent` | true | 2（前景） | 0，沒有明確指定 | `.result()` | 同上；不在即時動態上 |

### 2-1-3. perform 裡（包括呼叫的所有函式）有沒有需要前景的呼叫
| intent | 呼叫鏈 | 需要前景的呼叫 |
|---|---|---|
| 完成這組 | `WorkoutIntentActions.completeSet` → `WorkoutService.completeSet(id:)` → `complete` → `WorkoutActions.complete`（SwiftData 存檔）→ `RestTimer.start`（UserDefaults、`UNUserNotificationCenter` 的 `requestAuthorization`／`add`）→ `LiveActivityController.sync`（`Activity.activities`、`update`） | 沒有。沒有 `UIApplication` 的 API、沒有打開網址、沒有畫面。`Activity.request` 只在找不到這次訓練的即時動態時才呼叫，用 `try?`，在背景失敗也不影響。`requestAuthorization` 在已經授權時不會跳視窗；而且「跳過休息」根本不會呼叫它，照樣要求解鎖。 |
| 跳過休息 | `RestTimer.skip`（UserDefaults、取消通知）→ `sync` | 沒有 |
| +15 秒 | `RestTimer.adjust`（UserDefaults、重新排程通知）→ `sync` | 沒有 |

DEBUG 版這次多了 `UIApplication.shared.isProtectedDataAvailable`、`applicationState`，只讀取，不影響前景或背景。

### 2-1-4. 實際裝到手機的簽署
裝到手機那一版是 11/01 00:05 建置的 CHANGE_16 版本，用 `codesign -d --entitlements` 讀出。Team ID 以 `<TEAM>` 表示。

| 項目 | App（com.aaronhou.LiftLog） | 小工具擴充（…LiftLogWidgets） |
|---|---|---|
| entitlements | `application-identifier`、`com.apple.developer.team-identifier`、`get-task-allow`=true、`com.apple.developer.healthkit`=true、`healthkit.access`=[]、`com.apple.security.application-groups`=[group.com.aaronhou.LiftLog] | `application-identifier`、`team-identifier`、`get-task-allow`=true、`application-groups`=[group.com.aaronhou.LiftLog] |
| **`com.apple.developer.default-data-protection`** | **沒有** | **沒有** |
| embedded.mobileprovision | Xcode 管理的「iOS Team Provisioning Profile」（免費帳號），7 天，1 台裝置。Entitlements：healthkit、healthkit.background-delivery、healthkit.access [health-records]、application-groups、keychain-access-groups、get-task-allow。沒有 data protection。 | 同上類型。Entitlements：application-groups、keychain-access-groups、get-task-allow。 |
| Info.plist（和即時動態、背景相關） | `NSSupportsLiveActivities`=true；**沒有 `UIBackgroundModes`**；`CFBundleURLTypes`（liftlog）；`UIApplicationSupportsMultipleScenes`=true；MinimumOSVersion 26.0；SDK iphoneos27.2 | `NSExtensionPointIdentifier`=com.apple.widgetkit-extension，沒有其他相關設定 |

### 2-1-5. 資料存放的位置和保護等級
| 資料 | 位置 | 保護等級 |
|---|---|---|
| SwiftData 資料庫 | App 資料容器 `Library/Application Support/LiftLog4.store`（加上 -wal、-shm）；`groupContainer: .none` | 沒有在程式裡指定。沒有 data-protection entitlement，所以是系統預設的「第一次解鎖之後」（`completeUntilFirstUserAuthentication`，Core Data 的預設也是這個）。 |
| UserDefaults.standard（設定、休息倒數 `restTimer.endDate`／`duration`） | App 資料容器 `Library/Preferences/com.aaronhou.LiftLog.plist` | cfprefsd 管理，系統預設 |
| App Group 的 UserDefaults（小工具快照、待處理的深層連結） | 群組容器 `Library/Preferences/group.com.aaronhou.LiftLog.plist` | 系統預設 |
| 休息倒數的狀態 | 同 UserDefaults.standard | 同上 |
| 診斷紀錄（CHANGE_17，DEBUG） | 群組容器 `Library/Diagnostics/intent-log.jsonl` | `.none`（資料夾和檔案） |

- 資料保護不是原因：系統在呼叫 App 之前就要求解鎖，App 根本沒有機會讀寫資料。
- 手機上的實測值：perform 沒有執行，所以「開始」那一筆記錄的各檔案保護等級在手機上沒有記到。
- 模擬器沒有資料保護，讀出來是「未設定」。

---

## 3. 2-2 診斷紀錄（只在 DEBUG）
- `Shared/IntentDiagnostics.swift`（App 和小工具共用）：
  - 每一筆寫成一行 JSON，存在 App Group 容器 `Library/Diagnostics/intent-log.jsonl`；資料夾和檔案的保護等級都是 `.none`，鎖定時也寫得進去。
  - 同一筆也寫進系統日誌（subsystem `com.aaronhou.LiftLog`，category `intent`，訊息開頭 `LiftLogDiag`），可以和手機的系統日誌對照。
  - 時間含毫秒和時區。
- 三個 intent 的 perform（`LiftLog/Intents/WorkoutIntents+App.swift`）：
  - 「開始」記下：參數、`isProtectedDataAvailable`、`applicationState`、資料庫／UserDefaults／App Group／紀錄檔的保護等級、即時動態的狀態、休息倒數。
  - 「成功」或「失敗」記下：結果（`completed`、`alreadyCompleted`、`notFound`、`cannotComplete`；跳過休息和 +15 秒在沒有休息時算失敗）、之後的即時動態和休息倒數。
- 小工具擴充的空 perform 也寫一筆「小工具擴充執行（空的實作）」，看得出系統在哪一個程序執行。
- 另外記「App 啟動」（App 的程序什麼時候被叫起來）和「存檔失敗」（`WorkoutActions.save` 的錯誤）。
- 設定 sheet 最下面多一列「診斷紀錄」：最近 50 筆、新的在上面、可以下拉重新讀取、右上角「清除」（置中的 alert，有「取消」）。
- 全部在 `#if DEBUG` 裡（S1）。Release 版不改任何行為：`WorkoutActions.save` 在 Release 照舊是 `try? context.save()`。
- 取出方式：
  ```
  xcrun devicectl device copy from --device <UDID> --domain-type appGroupDataContainer \
    --domain-identifier group.com.aaronhou.LiftLog --source Library/Diagnostics/intent-log.jsonl --destination tools/fixtures/…
  ```
  實測可行，不用截圖。
- 單元測試 `IntentDiagnosticsTests`（4 個）：
  - 寫入後讀回、新的在前、拿不到的值是 nil。
  - 時間含毫秒和時區。
  - 只列最近 50 筆。
  - 保護等級是 None（模擬器上沒有值時是「未設定」）、沒有檔案時是「沒有檔案」。
  - 清除後可以繼續寫。

---

## 4. 收斂標準的結果

| 項目 | 結果 | 驗證方式 |
|---|---|---|
| G1 Debug、Release 0 error 0 warning | **通過** | clean build 三種：Debug（含測試 target，`build-for-testing`）、Release 模擬器、Release 實機（`CODE_SIGNING_ALLOWED=NO`），`grep -c 'error:'`、`grep -c 'warning:'` 都是 0。實機用的 Debug 版（`-allowProvisioningUpdates`）也是 0／0。Release 的 App 和小工具執行檔裡找不到 `LiftLogDiag`（0 處），診斷紀錄沒有編進 Release。 |
| G2 全部測試通過 | **通過** | 乾淨安裝後跑全部測試：**321 個全部通過**（CHANGE_16 的 317 個，加上 `IntentDiagnosticsTests` 4 個）。這次沒有改到邏輯，沒有修正可以測。 |
| D1 鎖定時三個按鈕都不會要求解鎖 | **未達成（停在 §3）** | 重現時「完成這組」要求解鎖。原因在 iOS，見第 1、5 節。 |
| D2 診斷紀錄顯示三個 intent 都執行且成功 | **未達成** | 手機上沒有任何一筆「開始」：perform 沒有被執行。模擬器上「完成這組」執行而且成功（對照組）。 |
| D3 解鎖打開 App 後已經同步 | **未達成** | 使用者回報「打開後沒有打勾」，和 perform 沒有執行一致。 |
| S1 診斷紀錄的程式全部在 `#if DEBUG` 裡 | **通過** | 腳本掃描所有 Swift 檔：41 處提到 `IntentDiagnostics`，唯一不在 `#if DEBUG` 區塊裡的是一行註解；4 個新檔案整個包在 `#if DEBUG`／`#endif`。CLAUDE.md 的 UserDefaults 字面 key 檢查：38 處，全部在 `#if DEBUG` 裡。 |
| S2 診斷紀錄、系統日誌、所有輸出都在 `tools/fixtures/`，沒有 commit | **通過** | `git status` 只有使用者自己的 pbxproj 簽署設定；`git log --all -- tools/fixtures` 是 0 個 commit；`git ls-files tools/fixtures` 是 0。輸出在 `tools/fixtures/change17/`：診斷紀錄 2 份、logarchive、篩選後的文字檔、裝置資訊。 |

---

## 5. 有沒有遇到「先停下來」的情況：**有（§3）**

規格寫的是：「如果原因是 iOS 本身的限制（例如免費開發者帳號不允許，或某個必要的動作一定要解鎖），先停下來：在報告裡附上證據和可行的替代做法，不要自己改成別的設計」。

- **證據**：第 1 節。
  - 系統在呼叫 App 之前就要求解鎖，App 的程式沒有機會執行。
  - App 已經做了能做的宣告：明確 alwaysAllowed、只在背景、不打開 App。系統也收到了。
  - 手機 iOS 27.2 的 chronod 對這次互動套用了「鎖定時要驗證」，沒有公開的 API 能改。
- **還不能區分的兩種情況**：
  - (a) iOS 27.2 對所有第三方即時動態按鈕都這樣；
  - (b) 和免費開發者帳號、開發版簽署這類條件有關。
  - 不管哪一種，App 的程式都沒辦法讓它不用解鎖。
- **可行的替代做法**（沒有實作，等使用者決定）：
  1. **先分辨是 (a) 還是 (b)，不改程式**（建議先做）：在手機上找另一個有即時動態按鈕的第三方 App，鎖定、讓 Face ID 認不到臉時按它的按鈕。
     - 也要求解鎖：是 iOS 27.2 的行為。
     - 不要求：和 LiftLog 的簽署方式有關。免費帳號沒辦法改，要付費開發者帳號（TestFlight 或 Ad Hoc 簽署）才能比較。
  2. **維持現狀，靠 Face ID**：要求解鎖時如果 Face ID 認得出臉，會在背景直接通過，動作接著執行；只有 Face ID 看不到臉（手機平放在地上、椅子上）時才要輸入密碼。這要實機確認：Face ID 通過後動作有沒有繼續執行、還是要再按一次。不用改程式。
  3. **回報 Apple**（Feedback Assistant），附上第 1-3 節的日誌：iOS 27.2 上明確宣告 `alwaysAllowed` 的 `LiveActivityIntent` 在鎖定畫面仍要求解鎖。iOS 更新後，用這次的診斷紀錄（DEBUG 版設定最下面）照 2-3 的步驟再測一次。
  4. 不建議：
     - 把 intent 改宣告成其他系統協定（例如 `AudioPlaybackIntent`）來繞過。這改變了設計和語意，而且在 27.2 上不確定有效。
     - 改用控制中心的控制項。ChronoCore 對控制項走同一套互動政策，預期一樣要解鎖。

---

## 6. 自行決定的事項

**調查方法**
1. 診斷紀錄放在 **App Group 容器**，不放 App 的資料容器：小工具擴充也能寫，看得出系統在哪一個程序執行 perform；devicectl 也讀得到 App Group 容器（`--domain-type appGroupDataContainer`），不用請使用者截圖。
2. 小工具擴充的空 perform 也寫紀錄，另外加「App 啟動」「存檔失敗」兩種。規格只要求三個 intent 的開始、成功、失敗；多記這些才看得出 App 的程序有沒有被叫起來、資料庫有沒有寫失敗。
3. 2-3 的步驟另外加了三件事，好讓證據更確定：
   - 「讓 Face ID 認不到臉，確認鎖頭是關著的」：不然 Face ID 會悄悄解鎖，測不到鎖定的情況。
   - 「出現解鎖畫面時不要輸入密碼，取消後看即時動態有沒有變」：區分 perform 是在解鎖前還是解鎖後執行。
   - 「再按跳過休息」。
   
   使用者在第 4 步取消後即時動態沒有變，沒有進入休息，所以沒有按到「+15 秒」「跳過休息」。這兩個以前就確定一樣要求解鎖（第 1 節「已知的事實」）。
4. 手機的系統日誌用 `sudo -A log collect --device-udid`，搭配 Mac 上跳出的密碼對話框（osascript），由使用者輸入管理員密碼；不用 root 時 `log collect` 會拒絕。
5. 日誌沒有寫原因，所以讀了系統框架的程式碼（WorkflowKit、ChronoCore、ChronoServices、LinkMetadata、LinkServices、VoiceShortcutClient、WidgetRenderer），只讀、不改：
   - 手機 27.2 的版本：Xcode 的 iOS DeviceSupport。
   - iOS 27.1 模擬器 runtime 的共用快取（用 Xcode 附的 `dsc_extractor` 取出）。
   
   結論以手機 27.2 的版本為準。中間產物在 scratchpad，沒有放進 repo。
6. 確認 metadata 編號的實驗建置在暫存的 git worktree 做，做完刪掉，沒有 commit。
7. 試過用 lldb 掛上模擬器的系統程序看實際的值，SIP 不允許（`Not allowed to attach to process`），沒有關掉 SIP。

**程式**
8. 診斷紀錄（DEBUG）保留，不刪：iOS 更新後或改簽署方式後，照 2-3 的步驟重測時直接用。Release 版沒有任何差別。
9. `WorkoutIntentActions.completeSet` 改成回傳結果（`@discardableResult`），讓診斷紀錄寫得出是 `completed` 還是其他；行為不變。
10. §3 沒有修改任何行為。CompleteSetIntent 的 `authenticationPolicy = .alwaysAllowed` 照舊；「跳過休息」「+15 秒」也沒有補上明確宣告，因為已經證實明確宣告也沒有用（第 1 節）。
11. 這一輪停在 §3：
    - 報告和文件都 commit 在本機，**還沒有推上 GitHub**，§6 的更新簽署也還沒做，等使用者決定之後一起做。
    - 手機上現在是診斷版，簽署到期日照舊。

---

## 7. 未解決的事項
- **沒有觸發規則 3**（沒有任何修正嘗試）。
- **D1～D3 未達成**：原因在 iOS 27.2（第 1、5 節），等使用者決定替代做法。
- 還不能區分「iOS 27.2 對所有第三方即時動態按鈕都要求驗證」和「和免費帳號、開發版簽署有關」（第 5 節替代做法 1）。
- WidgetRenderer 依什麼條件決定即時動態的 `keybagLockPolicy`／互動政策，沒有查到：系統框架的程式碼大多是去掉符號的 Swift，日誌值是 `<private>`，而且 SIP 不允許 lldb 掛上系統程序。
- 「App 從切換器滑掉之後按鈕還能不能用」等 CHANGE_16 第 6 節的其他實機項目，等鎖定的問題有結論後一起確認。

---

## 8. 實機確認清單（使用者決定之後）
1. （替代做法 1）用另一個有即時動態按鈕的第三方 App，在鎖定、Face ID 認不到臉時按按鈕，看會不會要求解鎖。
2. （替代做法 2）LiftLog 鎖定時看著手機按「完成這組」：Face ID 通過後那一組有沒有完成、即時動態有沒有切到休息，還是要再按一次。
3. 診斷紀錄：設定 → 最下面「診斷紀錄」看得到這次的「完成這組・開始／成功」。

---

## 9. commit 列表
```
548da4c CHANGE_17 §2-2: DEBUG diagnostics log for the Live Activity intents
d94b203 CHANGE_17 §0: save the prompt, mark CHANGE_16 as not converged
```
加上這份報告和文件的 commit（§2-3 調查結果、§3 先停下來）。
