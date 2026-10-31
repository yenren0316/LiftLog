# CHANGE_16 鎖定畫面不用解鎖就能完成一組：最終報告

- 日期：2026-10-31
- 範圍：§0 存原文；§1 即時動態加上「完成這組」：非休息時顯示「下一組：臥推・第 3／8 組」和這一組會記錄的值，主要按鈕「完成這組」帶著那一組的 id，和 App 裡打勾同一個函式；沒有可以記錄的值時「打開 App 填寫」，全部完成時「全部完成，打開 App 結束訓練」；防止重複。每一節各自 commit，都是建置成功、全部測試通過後才 commit。CLAUDE.md 的執行規則 1～7 照常適用（這次沒有資料遷移，資料模型和備份格式都沒有改）。
- 結果摘要：**§1 完成，沒有遇到「先停下來」的情況**（第 2 節）。CHANGE_05 起即時動態就有一顆「完成這組」（完成「目前的組」，不帶 id），這次把它改成規格的樣子：intent 帶著組的 id、App 裡的 ✓ 和按鈕走同一個函式、顯示要記錄的值和三種狀態。除了單元測試，模擬器上真的即時動態也用 UI 測試按過三種情況（動態島展開、App 完全關掉、鎖定畫面），按下後即時動態切到休息，打開 App 時訓練畫面已經同步。
- 驗收時另外發現並修正：真的鎖定畫面上第 1 列的訓練名稱被經過時間擠掉（CHANGE_10 起就這樣，App 裡的預覽頁看不出來，第 3 節）。
- 驗證環境：Xcode 27.2（`/Applications/Xcode.app`，這次開始前更新；CoreSimulator 要跟著更新，`xcodebuild -runFirstLaunch` 需要管理員密碼，由使用者輸入後才能用模擬器），iPhone 17 Pro 模擬器（iOS 26.5），測試一律 `-parallel-testing-enabled NO`。最後的全部測試和截圖在乾淨安裝後用 seed＋示範訓練（`-demoData`），空資料（`-emptyData`）放在最後。這次沒有用到真實資料。
- 文件：`SPEC.md`（開頭摘要、訓練中畫面的打勾、休息計時器、主題配色的 done、即時動態整節（狀態、值的格式、鎖定畫面的版面、第 1 列、intent）、深層連結的 `-discardActive`、開發用參數、已移除）、`tools/STATUS.md`、`tools/changes/README.md`（加上 CHANGE_16）已更新；`tools/CHANGE_08_REPORT.md`（自行決定 23 的兩個連結）、`tools/CHANGE_10_REPORT.md`（自行決定 16 鎖定畫面的經過時間）加了粗體註記。CLAUDE.md 這次沒有要改的規則。

---

## 1. 收斂標準的結果

### 建置與測試
| 項目 | 結果 | 驗證方式 |
|---|---|---|
| G1 Debug、Release 0 error 0 warning | **通過** | 最後的程式 clean build 三種：Debug（含單元測試和 UI 測試 target，`build-for-testing`）、Release 模擬器（`generic/platform=iOS Simulator`）、Release 實機（`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO`），`grep -c 'error:'`、`grep -c 'warning:'` 都是 0（Xcode 27.2 在 CoreSimulator 更新前印的「CoreSimulator is out of date」不是編譯的警告，更新後也沒有了）。 |
| G2 全部測試通過 | **通過** | 最後的程式乾淨安裝後跑全部測試：**317 個全部通過**、0 失敗。單元測試 273（41 檔）＋UI 測試 44（17 檔＋共用）。CHANGE_15 結束時 302 個：單元新增 13（`CompleteSetIntentTests`）、刪掉 1（`WorkoutServiceTests.targetText`，搬到新的格式測試）；UI 新增 3（`LiveActivityUITests`）。 |

G2 要求的新測試（`LiftLogTests/CompleteSetIntentTests.swift`，資料是三天前一次訓練裡每種組各一組當灰字預填的來源，滑輪下拉從沒做過）：

| 規格要求 | 測試 | 結果 |
|---|---|---|
| 下一組的選擇：依順序第一個沒打勾的組；跨動作時換到下一個動作 | `nextSetIsTheFirstUncheckedSetInOrderAcrossExercises`：臥推 3 組＋滑輪下拉 3 組。一開始即時動態的 `setID` 是臥推第 1 組、「下一組：臥推・第 1／3 組」；先在 App 裡打勾第 2 組，下一組還是第 1 組；按「完成這組」後是第 3 組；再按一次換成「下一組：滑輪下拉・第 1／3 組」，`setID` 是滑輪下拉第 1 組 | 通過 |
| 記錄的值：已填的值優先，沒填用灰字預填的值；和 App 裡打勾的結果完全相同 | `recordedValueIsEnteredFirstThenPrefillSameAsTheAppCheck`：兩份一樣的資料，第 1 組都只填了 35 kg。一份按即時動態的「完成這組」，一份用 App 裡打勾的函式，兩組都做：記錄的值完全相同（第 1 組 35 kg × 3，次數用灰字預填；第 2 組全部用預填 32.5 kg × 3），所有組（包括沒打勾的第 3 組）的值和打勾狀態都一樣；即時動態按下前顯示的值就是記錄下來的值（`SetFormat.single`）。`shownValueFollowsWhatIsEntered`：改了次數，即時動態的值跟著變；lbs 也一樣 | 通過 |
| 沒有可以記錄的值時，不能完成，顯示「打開 App 填寫」 | `noRecordableValueCannotCompleteAndAsksToOpenTheApp`：滑輪下拉第 1 組沒填也沒有預填：`value` 是 nil、狀態是 `.needsInput`（文字「打開 App 填寫」）；就算 intent 被執行也回傳 `.cannotComplete`、沒有任何組被打勾、沒有開始休息。只填了 kg 時值是「40 kg」、狀態還是 `.needsInput`；填了次數才變成可以完成 | 通過 |
| 完成後自動開始休息倒數，即時動態變成休息狀態 | `completingStartsRestAndTheActivityRests`：按「完成這組」後第 1 組用預填打勾、休息 90 秒（臥推的角色是推）、排程休息結束的通知；即時動態的狀態是 `.resting`（沒有「完成這組」），下一組照樣顯示「下一組：臥推・第 2／3 組」；休息結束（系統標成過期）後回到 `.ready` 和下一組。`autoRestOffCompletesWithoutRest`：設定關掉自動休息時照樣完成、不開始休息 | 通過 |
| 最後一組完成後，即時動態顯示「全部完成，打開 App 結束訓練」 | `lastSetShowsAllDone`：輔助引體向上＋跑步機。第 1 組完成後開始休息；最後一組（跑步機）完成後不再開始新的休息，即時動態是 `.allDone`（文字「全部完成，打開 App 結束訓練」、沒有按鈕、`setID` 是 nil、已完成 2／2 組），就算前一組的休息還在倒數也一樣。`lastSetCheckedInTheAppDoesNotStartRestEither`：App 裡打勾最後一組也一樣。`workoutWithoutSetsIsNotAllDone`：還沒有任何組時是 `.noSets`，不是全部完成 | 通過 |
| 防止重複：用已經完成的組的 id 執行 intent，不會完成任何組 | `alreadyCompletedSetIsNotCompletedAgain`：即時動態顯示第 1 組時先在 App 裡打勾，再用即時動態上的 id 執行：回傳 `.alreadyCompleted`，所有組的值和打勾狀態完全不變，休息的結束時間和通知都沒有重來；更新後的即時動態顯示第 2 組。不在這次訓練裡的 id（組被刪掉）回傳 `.notFound`，也不改資料。`intentCarriesTheSetIDAndNeedsNoUnlock`：`CompleteSetIntent(setID:)` 帶著 id、`authenticationPolicy` 是 `.alwaysAllowed` | 通過 |
| 各種組的值的顯示格式（重量型、自重、輔助型的負重量、計時、跑步機） | `valueFormatForEveryKindOfSet`：重量型「32.5 kg × 3」、lbs「132.5 lbs × 5」；輔助引體向上的負重量「-20 kg × 5」、沒有重量「8 下」；輔助型（雙槓撐）「輔助 19 kg × 5」、0 是「自重 × 5」；自重「12 下」、有負重「+10 kg × 12」；計時「45 秒」、有負重「+24 kg × 60 秒」；跑步機「30 分鐘」、「坡度 12・速度 5.5・30 分鐘」；沒有值是 nil。`everyKindOfSetCompletesWithTheShownValue`：一次訓練裡輔助引體向上、雙槓撐、反式划船、棒式、跑步機各一組，每一組即時動態顯示的值都是上面的格式，按「完成這組」後記錄下來的值用同一個格式寫出來還是一樣；最後是全部完成 | 通過 |

模擬器上真的即時動態（`LiftLogUITests/LiveActivityUITests.swift`，示範訓練的第一個動作是臥推，示範資料有上一次）：

| 測試 | 內容 | 結果 |
|---|---|---|
| `testCompleteSetFromTheExpandedIsland` | 回主畫面、長按動態島展開：有「下一組：臥推」和「完成這組」；按下（App 在背景）後展開的動態島切到休息（「跳過休息」，沒有「完成這組」）；打開 App：臥推第 1 組「已完成」、第 2 組「未完成」、休息倒數在跑 | 通過 |
| `testCompleteSetWhenTheAppIsClosed` | 示範訓練開始後把 App 完全關掉（XCUITest 的 terminate），即時動態還在；展開動態島按「完成這組」：系統把 App 帶起來執行，即時動態切到休息；再打開 App（重新啟動）：第 1 組已完成、第 2 組沒有、休息倒數在跑（從資料庫和 UserDefaults 讀出來） | 通過 |
| `testCompleteSetOnTheLockScreen` | 經過 1:05:30 的示範訓練。用模擬器的側邊按鈕鎖定再亮起鎖定畫面（不解鎖）：即時動態有訓練名稱、完整的「1:05:48」、「下一組：臥推・第 1／3 組」、「55 kg × 8」、「完成這組」；在鎖定畫面按下後切到休息；解鎖（模擬器沒有密碼）後打開 App 已經同步 | 通過 |

打勾按鈕加了無障礙值「已完成／未完成」，UI 測試用它判斷打勾狀態（VoiceOver 也會讀出來）。

改寫或刪掉的測試：
- `WorkoutServiceTests`：`completeCurrentSet()` 刪掉了，改成按即時動態上的 id（`completeSet(id:)`）；`target` 改名 `value`；`targetText` 刪掉，格式的測試搬到 `CompleteSetIntentTests.valueFormatForEveryKindOfSet`（格式也改了：計時有負重「+24 kg × 60 秒」，以前是「24 kg・60 秒」）。

### 程式碼檢查
| 項目 | 結果 | 檢查方式 |
|---|---|---|
| S1 完成這組的 intent 呼叫和 App 裡打勾同一個函式，沒有另外的完成邏輯 | **通過** | 完成一組只有一個函式 `WorkoutService.complete(_:)`（`Logic/WorkoutService.swift`）：預填值用 `SetRecord.placeholder`（和畫面的灰字同一份 `setHints`）、`WorkoutActions.complete` 打勾、還有下一組時 `startRest`。呼叫的地方：App 裡的 ✓（`WorkoutEditor.toggle`，訓練畫面和編輯訓練共用）和即時動態（`CompleteSetIntent.perform` → `WorkoutIntentActions.completeSet(id:)` → `WorkoutService.completeSet(id:)` 找到那一組後呼叫 `complete`）。`grep`：`WorkoutActions.complete(` 在 App 的程式裡只剩 `WorkoutService.complete` 一處；`isCompleted = true` 只在 `WorkoutActions` 的 `apply`（打勾、完成訓練的「全部標為完成」、編輯時「標為完成」共用）。以前 App 的 ✓ 自己呼叫 `WorkoutActions.complete` 再由 `onSetCompleted` 開始休息、intent 另外走 `completeCurrentSet`，兩條路都刪掉了。 |
| S2 新增的 DEBUG 參數都在 #if DEBUG 裡 | **通過** | 沒有新增參數：`-widgetGallery` 多一個值 `liveStates`，`-discardActive` 多停掉休息倒數，都在原本的 `#if DEBUG` 裡。腳本列出所有 `UserDefaults.standard.<bool|string|integer|double|object>(forKey: "字面值")`：38 處，全部在 `#if DEBUG` 區塊內。 |

### 畫面驗證（`tools/screens/change16/`）
| 項目 | 結果 | 說明 |
|---|---|---|
| V1 鎖定畫面的即時動態，非休息狀態，有「完成這組」和要記錄的值（DEBUG 預覽） | **通過** | `V1_lock_preview.png`（`-widgetGallery live`）：第一張是規格的例子「上肢速度與爆發・臥推／下一組：臥推・第 3／8 組／32.5 kg × 3／完成這組」；第二張是最長的名稱和值（名稱截斷、組數完整、「坡度 12.5・速度 5.5・30 分鐘」完整）；第三張是休息（照舊「跳過休息」「+15 秒」）。三張都是 150 pt（上限 160）。另外 `V1_lock_real_ready.png`、`V1_lock_real_resting.png` 是模擬器上真的鎖定畫面（UI 測試截取）：按下前和按下後。 |
| V2 動態島展開，非休息狀態 | **通過** | `V2_island_preview.png`（`-widgetGallery island`）：縮小和最小沒有按鈕（「12/12」、休息倒數、啞鈴），展開的非休息是「DE 上肢／下一組：臥推・第 3／8 組／32.5 kg × 3／完成這組」，140 pt。`V2_island_real_ready.png`、`V2_island_real_resting.png` 是模擬器上真的動態島（UI 測試截取）：「下一組：臥推・第 1／3 組」「55 kg × 8」「完成這組」，按下後切到休息、「下一組：臥推・第 2／3 組」。 |
| V3 沒有可以記錄的值時的「打開 App 填寫」 | **通過** | `V3_V4_live_states.png`（`-widgetGallery liveStates`）第一張：「下一組：滑輪下拉・第 1／3 組」、值是「—」（次要文字色）、按鈕的位置是次要文字「打開 App 填寫」；最下面是動態島展開的同一個狀態。 |
| V4 全部完成時的「全部完成，打開 App 結束訓練」 | **通過** | `V3_V4_live_states.png` 第二張：打勾圖示（done）、「全部完成，打開 App 結束訓練」、「已完成 14／14 組」，沒有按鈕，150 pt。 |
| （每輪重跑）歷程穩定性 | **通過** | 紀錄、統計、動作庫第 1 層、分類清單（核心）各 0.5 秒連拍 5 張，遮掉最上面 200 px 比對都「全部相同」（`stability_pixel_compare.txt`）。 |

截圖逐張看過：沒有不該有的截斷或重疊（第 1 列的名稱問題見第 3 節，已修），即時動態的顏色是主題的 accent、done 和系統的白色／次要色，和以前一樣。空資料（`E_today.png`、`E_library.png`）：首頁「ME 下肢」「主項：—」「3 個動作」，動作庫是說明文字和 9 個「0 個動作」，和 CHANGE_15 一樣。

---

## 2. 有沒有遇到「先停下來」的情況：沒有

規格的條件是「LiveActivityIntent 在免費開發者帳號上不能用，或沒辦法在不解鎖的狀態下執行」。查的方式和結果：
- **免費帳號**：LiveActivityIntent 不需要任何付費的 capability（不用推播；即時動態由 App 在本機用 ActivityKit 更新）。CHANGE_05 起「跳過休息」「+15 秒」就是同一套 LiveActivityIntent，一直用免費帳號簽署安裝；CHANGE_08 的實機確認第 4 項在手機的鎖定畫面按過「跳過休息」「+15 秒」。這次的「完成這組」只是多帶一個參數（`@Parameter var setID`），簽署和權限都沒有變。
- **不用解鎖**：
  - App Intents 的 `authenticationPolicy` 預設是 `.alwaysAllowed`（Xcode 27.2 SDK 的 `AppIntents.swiftinterface`；另外兩個是 `.requiresAuthentication`、`.requiresLocalDeviceAuthentication`）；`CompleteSetIntent` 把它寫明。
  - intent 要寫的資料：SwiftData 的資料庫和 UserDefaults 都沒有設定資料保護等級（entitlements 沒有 `com.apple.developer.default-data-protection`），用系統預設的「第一次解鎖之後」（`completeUntilFirstUserAuthentication`），手機開機解鎖過一次之後，鎖定時也能讀寫。
  - 模擬器：鎖定畫面上按「完成這組」不解鎖就完成了那一組並切到休息（`testCompleteSetOnTheLockScreen`）。模擬器沒有密碼，所以「有密碼的手機鎖定時」只能在實機確認（第 6 節第 1 項）。
- 所以照規格做，沒有改成需要解鎖的做法。

---

## 3. 驗收時發現的問題：鎖定畫面第 1 列的訓練名稱被擠掉

- 現象：第一次在模擬器上截到真的鎖定畫面，第 1 列只有右邊的經過時間，左邊的訓練名稱不見了。動態島展開時名稱和經過時間在系統的左右兩個區域，沒有這個問題；App 裡的預覽頁也看不出來（App 裡的計時文字只佔顯示的寬度）。
- 原因：CHANGE_10 §0-4 把經過時間改成不設寬度上限、`layoutPriority(1)`；小工具裡的計時文字（`Text(_, style: .timer)`）會佔走剩下的全部寬度，名稱被擠成 0。
- 修正：名稱 `layoutPriority(1)` 先排、太長時截斷名稱；經過時間至少保留 64 pt（`LiveActivityLayout.elapsedMinWidth`，放得下「1:05:30」）。修正後真的鎖定畫面上「上肢訓練」和「1:05:48」都完整（`V1_lock_real_ready.png`），預覽頁最長的名稱「下肢速度與爆發・坐姿分腿壺鈴三點…」和「1:05:34」也是。
- 規格沒有要求，但 CLAUDE.md 要求截圖沒有不該有的截斷，而且這一列在「完成這組」的畫面上，所以一起修。

---

## 4. 自行決定的事項

**沿用與單一函式**
1. CHANGE_05 的「完成這組」（`CompleteSetIntent`、`Button(intent:)`、`LiveActivityController` 同步）照舊沿用，這次改的是：intent 帶組的 id、完成走 App 裡打勾的同一個函式、顯示的內容和狀態。「跳過休息」「+15 秒」沒有改。
2. 單一的完成函式放在 `WorkoutService.complete(_:)`：App 裡的 ✓ 和即時動態都呼叫它。預填值在函式裡用 `SetRecord.placeholder` 算（和畫面上灰字同一份 `setHints`），不從畫面傳進來，所以兩邊用的一定是同一份。`WorkoutEditor` 的 `onSetCompleted` 和 `WorkoutView.setCompleted` 刪掉（休息改在函式裡開始；編輯已結束的訓練時不是進行中的訓練，不會開始休息，和以前一樣）。
3. **最後一組完成後不開始休息**（App 裡和即時動態都一樣，因為是同一個函式）：規格同時要求「按下後開始休息、即時動態切到休息狀態」和「最後一組完成後顯示全部完成、沒有按鈕」，只有最後一組不開始休息時兩條才一致（不然最後一組完成後會是休息狀態，有「跳過休息」「+15 秒」兩顆按鈕，休息結束還會跳「開始下一組吧！」的通知）。「最後一組」是打勾之後沒有任何沒打勾的組；前面還有漏掉的組時照樣開始休息，即時動態的下一組是那一組。已經在倒數的休息（前一組開始的）不停掉。
4. 全部打勾時，就算前一組的休息還在倒數，即時動態也顯示全部完成（全部完成比休息優先）。

**intent**
5. intent 帶的 id 就是即時動態上顯示的那一組；按下時那一組還沒打勾就完成它，不再檢查它是不是「第一個沒打勾的組」（例如 App 裡剛換了順序）：按鈕上寫的就是這一組。
6. 防止重複的三種情況都不改資料、只重新同步即時動態：那一組已經完成（`.alreadyCompleted`）、已經不在這次訓練裡或沒有進行中的訓練（`.notFound`）、沒有可以記錄的值（`.cannotComplete`，正常情況按鈕不會出現）。
7. `CompleteSetIntent` 明寫 `authenticationPolicy = .alwaysAllowed`（系統預設就是），讓「不用解鎖」寫在程式裡；「跳過休息」「+15 秒」照舊用預設，沒有改。
8. 有 `@Parameter` 的 intent 不能整個型別標 `nonisolated`（Swift 6 會報「'nonisolated' cannot be applied to mutable stored properties」；改用 `nonisolated(unsafe)` 會有警告）。改成 `struct CompleteSetIntent: nonisolated LiveActivityIntent`，系統會用到的成員（`title`、`isDiscoverable`、`authenticationPolicy`、`init()`、`perform()`）各自標 `nonisolated`；App 和小工具兩個 target（Swift 6 預設 MainActor、Swift 5）都沒有錯誤和警告。另外兩個沒有參數的 intent 照舊。

**顯示**
9. 值的格式（`SetFormat.single`）：欄位的順序和名稱跟訓練畫面一樣，重量的寫法用摘要（`SetFormat.compact`）同一個函式（單位、顯示精度、自重和計時的「+」、輔助型的「輔助」、0 的「自重」）。有重量時次數寫「× 3」，沒有重量時「12 下」；計時「45 秒」；跑步機用訓練畫面的欄位名稱「坡度 12・速度 5.5・30 分鐘」（摘要的 compact 是「坡度 12%・5.5 km/h・30 分」，摘要沒有改）。
10. **負號沒有改成例子的「−」**：規格的例子是「−20 kg × 5」，但規格也要求和 App 裡一致，而 App 裡負的重量（訓練畫面的灰字預填「-19」、上一次「-19 × 5」、摘要「-20 kg × 5 下」）都是系統數字格式的「-」。要用「−」就得改 App 裡所有負重的顯示，不在這次的範圍，所以即時動態跟著 App 用「-」。
11. 「第 3／8 組」用全形斜線，和休息狀態、SPEC 一樣（例子是「3/8」）；動態島縮小的「2/5」照舊。
12. 非休息的版面：②「下一組：臥推・第 3／8 組」（次要文字，和休息狀態的「下一組」同一個元件；名稱太長時只截斷名稱，組數一定完整）③ 要記錄的值（大字，鎖定畫面 title2、動態島 title3，放不下時縮小到 60%，不截斷）④「完成這組」。以前 ② 的角色標籤（「DE 主項」）拿掉了，角色只剩動態島縮小時左邊的圖示。高度照舊 150／140 pt。
13. 沒有可以記錄的值：③ 顯示已經填的部分（例如只填 kg「40 kg」），完全沒有時「—」，都是次要文字色（不是要記錄的值）；④ 是置中的次要文字「打開 App 填寫」，不是按鈕，點即時動態本身打開訓練畫面（`widgetURL`，和以前一樣）。以前的連結按鈕「打開 App 輸入這組」拿掉。
14. 全部完成：第 2～4 列整塊是打勾圖示（done 色，「完成的組」的意思）、「全部完成，打開 App 結束訓練」、小字「已完成 N／M 組」，沒有按鈕；以前的「全部的組都完成了」和連結按鈕「打開 App 完成訓練」拿掉。
15. 這次訓練還沒有任何組時（自由選動作、還沒加入動作）顯示「打開 App 加入動作」，不寫「全部完成」（規格沒寫）；動態島縮小時是「—」。
16. 休息狀態照舊（「休息」、下一組、倒數、進度條、「跳過休息」「+15 秒」）。
17. 第 1 列的修正（第 3 節）。

**測試與 DEBUG**
18. 打勾按鈕加無障礙值「已完成／未完成」，UI 測試用它判斷。
19. 模擬器的鎖定用 XCUIDevice 的私有方法 `pressLockButton`（只在 UI 測試 target，XCUIDevice 沒有公開的鎖定方法）。乾淨安裝後第一次在鎖定畫面顯示時系統會問「要允許來自 LiftLog 的即時動態嗎？」，測試按「允許」。
20. `-discardActive YES` 和訓練畫面的「捨棄訓練」一樣，休息倒數一起停掉：以前留著，下一個 UI 測試的即時動態一開始就在休息、沒有「完成這組」（第一次跑 `testCompleteSetWhenTheAppIsClosed` 失敗的原因）。
21. 預覽頁：`-widgetGallery live` 改成三張（規格的例子、最長的名稱和值、休息），新的 `-widgetGallery liveStates` 放沒有可以記錄的值、全部完成和動態島展開的沒有可以記錄的值（四張放不下一個畫面）。範例的組 id 是 "preview"，預覽的「完成這組」按了只會更新即時動態，不會完成真的組（STATUS 以前列的「DEBUG 預覽頁的『完成這組』是真的 intent 按鈕」因此不會再改到資料）。
22. V1、V3、V4 照規格用預覽頁；另外附模擬器上真的鎖定畫面和動態島（UI 測試截取）。

**環境**
23. Xcode 這次開始前更新成 27.2，模擬器要 CoreSimulator 1174.21（系統裝的是 1174.9.2），`simctl` 和測試都會卡在 `xcodebuild -runFirstLaunch` 等管理員密碼；在背景執行它、使用者在 Mac 上輸入密碼後安裝完成。之前的編譯檢查用 `generic/platform=iOS Simulator`（不需要模擬器）。

---

## 5. 未解決的事項
- **沒有觸發規則 3**（沒有任何條件連續修 3 次還過不了）。UI 測試 `testCompleteSetWhenTheAppIsClosed` 第一次失敗是上一個測試留下的休息倒數（自行決定 20），改了 `-discardActive` 之後通過。
- 沒有「先停下來」的情況（第 2 節）。
- 只能在實機確認的項目列在第 6 節。模擬器沒有密碼，「有密碼的手機鎖定時不用解鎖」要在實機確認。
- App 在背景時按「完成這組」，訓練畫面如果還開著，回到 App 時那一列的輕觸覺（打勾的 impact）可能會在畫面更新時震一下；模擬器沒有觸覺，沒辦法確認（第 6 節第 3 項）。
- CHANGE_11 留下的兩個 DEBUG 小問題照舊（`-emptyData` 之後再 `-demoData` 沒有輪替順序、`-scrollToBottom 分類` 最後一列在分頁列後面），只影響開發用的參數。

---

## 6. 實機確認清單
1. **鎖定時按「完成這組」不用解鎖就生效**：手機有密碼、鎖定（螢幕亮著但不解鎖），在鎖定畫面的即時動態按「完成這組」：不會要求 Face ID 或密碼，那一組完成。
2. **按完切換成休息倒數**：按下後即時動態馬上變成「休息」、倒數、「跳過休息」「+15 秒」，沒有「完成這組」；倒數結束後回到下一組和「完成這組」。最後一組按完是「全部完成，打開 App 結束訓練」，沒有按鈕、也不會有「休息結束」的通知。
3. **打開 App 後訓練畫面同步**：解鎖、打開 App，訓練畫面那一組已經打勾（值和即時動態上顯示的一樣）、休息倒數在跑；這時有沒有多震一下。
4. **App 完全關掉時按鈕是否還能用**：在 App 切換器把 LiftLog 滑掉（即時動態如果還在），按「完成這組」：那一組完成、切到休息；打開 App 後一樣同步。（iOS 在使用者滑掉 App 時可能會結束它的即時動態；模擬器上用 XCUITest 關掉時即時動態還在，按鈕可以用。）
5. **顯示**：「下一組：臥推・第 3／8 組」和要記錄的值看不看得清楚；沒有預填的動作是「打開 App 填寫」；動態島展開時也有「完成這組」，縮小和最小沒有按鈕；第 1 列的訓練名稱和經過時間都在。
6. **重複按**：在 App 裡打勾之後馬上回到鎖定畫面按還沒更新的「完成這組」，不會多完成一組。

---

## 7. 截圖索引（`tools/screens/change16/`）
| 檔名 | 內容 | 標準 |
|---|---|---|
| `V1_lock_preview.png` | 預覽頁 `-widgetGallery live`：規格的例子（臥推・第 3／8 組、32.5 kg × 3、完成這組）、最長的名稱和值、休息 | V1 |
| `V1_lock_real_ready.png` | 模擬器上真的鎖定畫面：「上肢訓練」「1:05:48」「下一組：臥推・第 1／3 組」「55 kg × 8」「完成這組」（UI 測試截取） | V1（補充）、第 3 節 |
| `V1_lock_real_resting.png` | 在鎖定畫面按下後切到休息（不解鎖） | V1（補充） |
| `V2_island_preview.png` | 預覽頁 `-widgetGallery island`：縮小、最小（沒有按鈕）、展開的非休息（完成這組）和休息 | V2 |
| `V2_island_real_ready.png`、`V2_island_real_resting.png` | 模擬器上真的動態島展開：按下前、按下後切到休息 | V2（補充） |
| `V3_V4_live_states.png` | 預覽頁 `-widgetGallery liveStates`：沒有可以記錄的值（打開 App 填寫）、全部完成、動態島展開的沒有可以記錄的值 | V3、V4 |
| `app_after_island.png` | 動態島按完後打開 App：臥推第 1 組打勾、休息倒數 | §1 同步 |
| `app_after_closed.png` | App 完全關掉時按完，再打開 App | §1 同步 |
| `stability_<records｜stats｜library｜category>_1～5.png` | 捲到底部後每 0.5 秒連拍 | 歷程穩定性 |
| `stability_pixel_compare.txt` | 四組都「全部相同」 | 歷程穩定性 |
| `E_today.png`、`E_library.png` | 空資料的首頁、動作庫 | 空狀態 |

---

## 8. commit 列表
```
aa63c46 CHANGE_16 §1: complete the next set from the Live Activity without unlocking
97d9909 CHANGE_16 §0: save the prompt
```
加上最後一個文件 commit（這份報告、SPEC.md、STATUS.md、舊報告的註記、截圖）。
