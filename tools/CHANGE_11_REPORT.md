# CHANGE_11 改用 iOS 26 內建行為、跨日重算、清除舊程式與真實資料驗證：最終報告

- 日期：2026-10-29
- 範圍：§1 分頁列與「訓練中」橫條改用 iOS 26 內建、§2 日期改變時重算、§3 1RM 統一與清除舊程式、§4 鍵盤（4-1 收鍵盤、4-2 候選列）、§5 圖表行為統一、§6 動態島、§7 訓練狀態浮窗的高度、§8 備份加入設定、§9 用真實資料在模擬器驗證。每一節各自 commit，都是建置成功、測試通過後才 commit（§4 有兩個：先 commit 可以用的候選列，確認融不進鍵盤後再拿掉，見第 5 節）。CLAUDE.md 的執行規則 1～7 照常適用（這次沒有資料遷移，資料模型沒有改；備份格式從 version 6 升到 7，只多一個選填的欄位）。
- 同一則訊息裡的三點補充都照做：整個 `tools/fixtures/` 放進 .gitignore，§9 的所有輸出只放在那裡；報告和 commit 裡沒有任何實際數值（R1 只寫一致或不一致）；prompt 原文存成 `tools/changes/CHANGE_11.md`。
- 驗證環境：Xcode 27.1（`/Applications/Xcode.app`），iPhone 17 Pro 模擬器（iOS 26.5），測試一律 `-parallel-testing-enabled NO`。最後的截圖在乾淨安裝後用 seed＋示範訓練（`-demoData`），空資料（`-emptyData`）放在最後。**所有截圖都沒有真實資料**：真實備份只在 §9 匯入過一次，比對完馬上把 App 從模擬器移除，之後才重新安裝、截圖。
- 文件：`SPEC.md`（開頭摘要、分頁列、收起鍵盤、圖表的選取、估算 1RM、統計快取的重算時機、訓練狀態浮窗、訓練中畫面、動作詳情、備份格式與設定、動態島、主項進步卡、開發用參數、已移除）、`tools/STATUS.md`、`tools/changes/README.md`（加上 CHANGE_11）已更新；`tools/CHANGE_10_REPORT.md` 被推翻的條目加了粗體註記。

---

## 1. 收斂標準的結果

### 建置與測試
| 項目 | 結果 | 驗證方式 |
|---|---|---|
| G1 Debug、Release 0 error 0 warning | **通過** | 最後的程式（`8bd7e0f`）clean build 三種：Debug（含單元測試和 UI 測試 target，build-for-testing）、Release 模擬器、Release 實機（`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO`），`grep -c 'error:'`、`grep -c 'warning:'` 都是 0。 |
| G2 全部測試通過 | **通過**（候選列的兩項見下表） | 最後的程式（`8bd7e0f`）乾淨安裝後跑全部測試：**253 個全部通過**、0 失敗。單元測試 233（36 檔）＋UI 測試 20（7 檔＋共用）。CHANGE_10 結束時 270 個：刪掉自己寫的分頁列收起邏輯的測試（單元 18、UI 8）和隨舊程式刪掉的測試，加上這次新的。 |

G2 要求的新測試：

| 規格要求 | 測試 | 結果 |
|---|---|---|
| 跨日重算：23:59 到 00:01 會重算 | `StatsRefreshTests.foregroundRecomputesOnlyWhenTheDayChanged`：23:59 算過、00:01 回到前景要重算；跨過午夜（`NSCalendarDayChanged`）、時區或系統時間改變一律重算 | 通過 |
| 週日到週一，本週歸零 | `StatsRefreshTests.sundayToMondayResetsTheWeek`：記憶體裡的資料庫、週日 19:00 有一次訓練；`StatsCache` 在週日 23:59 算時本週 1 天，週一 00:01 回到前景後本週歸零、上週同期不含週日、「幾天前」和「最久沒練」從 0 變 1；再跨一次午夜變 2 | 通過 |
| 同一天回到前景不重算 | 同上兩個測試：同一天回到前景，快照的時間不變（沒有重算） | 通過 |
| 備份：包含設定時能來回還原 | `BackupTests.settingsRoundTrip`（每週目標、只有有氧的訓練也算、單位、四個進位、自動休息、即時動態、主題寫進 version 7 的備份，還原到另一份設定後全部一樣）、`automaticWeeklyGoalRoundTrips`（沒設定過每週目標時還原成自動） | 通過 |
| 備份：舊格式照樣能匯入 | `BackupTests.oldBackupWithoutSettingsKeepsCurrentSettings`：version 6、沒有 settings 的檔案匯入成功，設定維持目前的值 | 通過 |
| 動態島的標題 | `IslandTitleTests`：有日型時「DE 上肢」「ME 下肢」，沒有時「訓練」，鎖定畫面的名稱不變；舊版 App 建立的即時動態（沒有新欄位）照樣解碼 | 通過 |
| 候選值的計算（kg 欄有建議和沒有建議、目前值是空的、進位 2.5 kg／1 kg／5 lbs、去掉重複；次數欄處方 3 下、8～12 下、最小是 1） | `SetCandidatesTests` 8 個，在 commit `c0ac0e7` 全部通過 | **不適用**：候選列融不進 iOS 26 的鍵盤，照 §4-2 的規定拿掉（第 5 節），只為它存在的計算和測試在 `1985585` 一起刪掉 |
| UI 測試：點候選會填入這一格並跳到下一格；最後一格填完會收起鍵盤 | `CandidateBarUITests` 2 個，在 `c0ac0e7` 全部通過（點建議重量填入 kg 欄、跳到次數欄、候選換成 1～5；次數填完跳到下一組；最後一格填完收起鍵盤） | **不適用**：同上 |

其他新增的測試：
- 單元：`StatsCacheTests.oneEstimated1RMEverywhere`（主項進步卡、換算表的基準、DE 建議重量是同一個估算 1RM；90 天內沒有紀錄時取全期、主項進步卡不列）、`StatsRefreshTests.fakeNowParsesWithAndWithoutTimeZone`。
- UI：`TabBarMinimizeUITests` 2（往下捲分頁列縮小、附屬列的訓練中橫條照樣可以點、捲回頂端恢復；沒有訓練時沒有附屬列）、`KeyboardUITests.testWorkoutBlankAreasDismiss`（§4-1：組與組之間、說明列、動作標題都能收起鍵盤；kg 欄和次數欄上方沒有鍵盤列也沒有候選列）、`DetailChartUITests`（§5：點一下浮出數字、沒有「打開這次訓練」、2 秒後消失）、`TrainingStatusUITests` 2（§7：一般字級打開就看得到最後一列、不是全高、往下拖關閉；最大字級用全高、捲得到最後一列）、`DynamicIslandUITests.testExpandedShowsTheDayTypeShortName`（§6 的 V3）。
- 刪掉的測試：`TabBarAutoHideTests`（18）、`TabBarHidingUITests`（7）、`StatsScrollUITests.testHiddenTabBarDoesNotInterceptTaps`（分頁列不再隱藏）；`PlanTests` 的 ME 紀錄和 `RecentVolume`、`ActivityCalendarTests` 的 `dailyCounts`／`level`、`RecencyTests` 的 `trainingDays` 2 個、`ExerciseStatsTests` 裡 `defaultStep` 的 4 行、`SetLogicTests` 的 `SetLogic.finish` 2 個（都是隨第 3 節刪掉的程式）。

### 程式碼檢查
| 項目 | 結果 | 檢查方式 |
|---|---|---|
| S1 自己寫的分頁列收起邏輯全部刪除 | **通過** | `grep hidesTabBarOnScroll\|TabBarAutoHide`（App、共用、小工具、兩個測試 target）0 筆。`BottomInset`、`workoutMiniBarTop`、`TabBarAutoHideLog`、`-tabBarLog` 也一起刪掉。 |
| S2 使用 tabBarMinimizeBehavior 和 tabViewBottomAccessory | **通過** | `RootView.swift`：`.tabBarMinimizeBehavior(.onScrollDown)`；`WorkoutCoordinator.swift`：`tabViewBottomAccessory(isEnabled:)`（iOS 26.1 起）和 iOS 26.0 的 `tabViewBottomAccessory {}`。 |
| S3 第 3 節列出的舊程式 grep 0 筆 | **通過** | `MaxEffortRecords`、`MainLiftSummary`、`homeSummary`、`dailyCounts`、`ActivityCalendar.level` 在程式和測試裡都是 0 筆（SPEC.md「已移除」一節照規定記下名稱）。 |
| S4 沒有 ToolbarItemGroup(placement: .keyboard) | **通過** | `placement: .keyboard` 0 筆。 |
| S5 verify_real_data.py 不引用 App 的程式；real_backup.json 不在 git 裡 | **通過** | 腳本只 import Python 標準函式庫（argparse、json、math、sys、datetime、pathlib、zoneinfo），規則是照 SPEC.md 的文字自己寫的。`git check-ignore tools/fixtures/real_backup.json` 命中 `.gitignore` 的 `tools/fixtures/`；`git log --all -- tools/fixtures` 0 筆，`git log --all --name-only` 裡沒有任何 fixtures 的路徑。 |

另外：開發用參數的腳本檢查（列出所有 `UserDefaults.standard.<bool|string|integer|double|object>(forKey: "字面值")`）共 36 個，全部在 `#if DEBUG` 區塊內，包括這次新增的 `-importBackup`、`-fakeNow`、`-dumpStats`、`-demoWorkoutDayType`、`-demoWorkoutTitle`。

### 畫面驗證（`tools/screens/change11/`）
| 項目 | 結果 | 說明 |
|---|---|---|
| V1 分頁列縮小、訓練中橫條在系統的位置 | **通過** | `V1_tabbar_expanded.png`（分頁列展開，附屬列在分頁列上方：訓練名稱和「訓練中 0:08」兩行）、`V1_tabbar_minimized.png`（往下捲之後分頁列縮小成目前的分頁，附屬列和它同一列，只有「訓練中 0:11」一行）。由 UI 測試截取。 |
| V2 訓練狀態浮窗打開就看得到全部 | **通過** | `V2_training_status.png`（一般字級：高度剛好包住內容，上面看得到今天）、`V2_training_status_largest_text.png`（最大字級：全高）、`V2_training_status_largest_text_scrolled.png`（捲到最後一列）、`E_training_status.png`（空資料）。 |
| V3 動態島展開，名稱很長的訓練顯示「DE 上肢」 | **通過** | `V3_island_de_upper_expanded.png`：訓練名稱是「上肢速度與爆發・臥推・輔助引體向上・跑步機（很長的名稱）」，展開時左上角只有「DE 上肢」。模擬器上真的動態島（UI 測試回到主畫面、長按展開）。`V3_island_de_upper_compact.png` 是縮小的。 |
| V4 kg 欄和次數欄的鍵盤 | **未通過（照 §4-2 的退路）** | 候選列融不進鍵盤，照規格拿掉。拿掉之後：`V4_kg_keyboard.png`、`V4_reps_keyboard.png`，鍵盤上方沒有浮著的膠囊，也沒有任何列；kg 欄的建議重量照舊在說明列「建議 55 kg（60%）」和灰字預填。候選列融不進鍵盤的截圖：`V4_candidate_bar_*.png`（第 5 節）。 |
| V5 動作詳情的折線圖點一下浮出數字 | **通過** | `V5_detail_chart_peek.png`：浮出「7/24・58.4 kg」，沒有「打開這次訓練」；UI 測試另外確認 2 秒後消失。 |
| （每輪重跑）歷程穩定性 | **通過** | 紀錄、統計、動作庫第 1 層、分類清單（核心）各 0.5 秒連拍 5 張，遮掉最上面 200 px 比對都「全部相同」（`stability_pixel_compare.txt`）。 |

### 真實資料（R1）：**通過**
做法：乾淨安裝後，用 `-importBackup tools/fixtures/real_backup.json -fakeNow <時間點> -dumpStats tools/fixtures/app_1.json` 啟動一次；再用第二個時間點啟動一次（資料已經匯入，不重匯）。`tools/verify_real_data.py` 直接讀備份 JSON、照 SPEC.md 的規則自己算一次，逐項比對。兩個時間點由腳本從備份算出（備份最後一筆訓練的隔天中午；之後第一個週一 00:05），只寫在 `tools/fixtures/times.json`。每個時間點比對 87 個數值。

| 比對項目 | 時間點 1（最後一筆訓練的隔天中午） | 時間點 2（之後第一個週一 00:05） |
|---|---|---|
| 本週天數 | 一致 | 一致 |
| 本週組數 | 一致 | 一致 |
| 本週下肢組數 | 一致 | 一致 |
| 本週上肢組數 | 一致 | 一致 |
| 本週其他組數 | 一致 | 一致 |
| 本週有氧分鐘 | 一致 | 一致 |
| 上週同期（天數、組數、各部位、有氧） | 一致 | 一致 |
| 近 30 天各分類組數（9 類） | 一致 | 一致 |
| 推拉比 | 一致 | 一致 |
| 單邊次數 | 一致 | 一致 |
| 爆發次數 | 一致 | 一致 |
| 四個日型的上次日期、幾天前、上次主項、下次主項 | 一致 | 一致 |
| 「下一次」的日型 | 一致 | 一致 |
| 每個「主」動作的估算 1RM 和 60% 建議重量 | 一致 | 一致 |
| 動作庫各分類「最久沒練」天數 | 一致 | 一致 |

第 2 節的檢查（同樣只看是否成立，不看數字）：時間點 2 的本週六項都是 0；每個有紀錄的日型「幾天前」、每個分類的「最久沒練」都剛好多了兩個時間點之間的天數。
第一次比對就全部一致，沒有需要判斷是 App 錯還是腳本錯的地方。

---

## 2. 第 1 節：分頁列與「訓練中」橫條

規格列的三個「先停下來」的情況都沒有發生：
- **分頁列是系統的 TabView**：`RootView` 本來就是 `TabView` ＋ `Tab`，只是以前自己控制 `.toolbarVisibility`。
- **附屬列放得下橫條的內容**：附屬列展開時（`tabViewBottomAccessoryPlacement == .expanded`）放兩行（訓練名稱、「訓練中 0:42」），縮小時（`.inline`）只放「訓練中 0:42」一行；外框、背景都交給系統，拿掉了以前自己畫的膠囊和外框。
- **沒有訓練時可以隱藏附屬列**：iOS 26.1 起有 `tabViewBottomAccessory(isEnabled:)`。專案的最低版本是 26.0，26.0 沒有這個參數，所以 26.0 上改成沒有訓練時不加附屬列（`#available` 分開）；模擬器和一般的手機都是 26.1 以後，走系統的參數。

模擬器上量到的系統行為（不是 App 的程式）：往下捲分頁列就縮小；**往上捲時不會中途恢復，要捲回頂端才恢復**，有沒有附屬列都一樣（UI 測試用四種往上捲的手勢，有附屬列時試 12 次、沒有時試 6 次，只有剛好捲回頂端的 1 次恢復）。規格要「全部交給系統」，所以沒有加自己的條件；測試照實際的系統行為寫（捲回頂端恢復）。實機的手感列在第 7 節。

### 「自己寫、但 iOS 26 已經內建」的清單（這次沒有改）
| 現在的做法 | iOS 內建的做法 | 建議 |
|---|---|---|
| 經過時間 `ElapsedTimeText`、休息倒數 `RestTimerBar` 用 `TimelineView` 每秒（0.5 秒）重畫 | `Text(timerInterval:countsDown:)`、`ProgressView(timerInterval:)`：系統自己跳秒，不用整塊重畫（即時動態已經在用） | 建議改：省電、程式更少；要確認格式「1:05:30」一樣 **（CHANGE_12 §1 已改，格式一樣）** |
| 訓練中全螢幕和附屬列的橫條之間是一般的 `fullScreenCover` | `matchedTransitionSource` ＋ `.navigationTransition(.zoom)`（iOS 18 起）：從附屬列放大成全螢幕，像「音樂」的迷你播放器 | 建議改：和這次的附屬列搭配，展開和縮小的動畫由系統做 **（CHANGE_12 §2 推翻：附屬列裡的橫條不能當放大轉場的來源，系統只會從畫面中間放大；維持 fullScreenCover）** |
| 「今天」用自己的 `ScreenHeader` 畫大標題，並隱藏導覽列 | `navigationTitle` ＋ `.navigationBarTitleDisplayMode(.large)`，iOS 26 的捲動邊緣效果也會跟著 | 建議改：和其他三個分頁一致 **（CHANGE_12 §3 推翻：系統的大標題讓首頁超出一個畫面 32.5 pt；維持 ScreenHeader）** |
| 休息計時結束用本機通知 | AlarmKit（iOS 26）：倒數計時有系統的鎖定畫面和動態島介面，靜音時也會響 | 可以評估：要確認免費帳號能不能用、需不需要額外權限 |
| 點空白處收起鍵盤 `KeyboardDismissOnTap`（window 上的點擊手勢） | SwiftUI 只有 `.scrollDismissesKeyboard`，沒有內建的「點空白處」 | 保留 |
| 圖表的選取手勢 `PressThenDragGesture`（UIKit 長按） | Swift Charts 的 `chartXSelection`／`chartGesture` | 保留：CHANGE_10 §0-1 查到 SwiftUI 的手勢會擋住捲動；之後的 iOS 可以再試一次 |
| 按鈕回饋 `PressableButtonStyle`、可點的卡片 `TapSurfaceStyle` | iOS 26 的 `.buttonStyle(.glass)`／`.glassProminent` | 暫時保留：玻璃樣式不跟著主題 token；主要按鈕可以考慮 |
| 篩選膠囊 `FilterCapsule` | `Picker(.segmented)` 或 `glassEffect` 的膠囊 | 保留：多選的篩選沒有完全對應的內建元件 |
| 訓練狀態浮窗自己量內容高度（§7） | iPhone 的 sheet 沒有「依內容高度」的內建 detent（`presentationSizing(.fitted)` 不影響 iPhone 的 sheet 高度） | 保留 |
| 欄位不齊全時左右晃動 `Shake` | `symbolEffect(.wiggle)` 只能用在 SF Symbol | 保留 |

---

## 3. 第 3 節：1RM 統一與刪掉的程式

**1RM**：全 App 只剩 `PersonalRecords.estimated1RM`（Epley，1～10 下的正式組和 MAX 組，不分角色，近 90 天最好的一次，沒有就取全期）。強度換算表的基準和 DE 建議重量本來就用它；主項進步卡以前自己算「明天往前 90 個日曆日」的最大值，現在改呼叫同一個函式。「和 4 週前相比」用同一個函式在 4 週前那時候算（90 天內沒有就取全期），所以有些以前顯示「和 4 週前一樣」的主項現在會顯示差距（示範資料的深蹲就是）。資料裡的舊角色值（「主項」「推」）照規定保留、沒有遷移。

**刪掉的程式**（零引用或只為它們存在）：
| 程式 | 原因 |
|---|---|
| `MaxEffortRecords`（PlanBuilder.swift） | 規格指定；ME 紀錄已經不用在建議重量（CHANGE_10）和任何畫面 |
| `MainLiftSummary`（HomeStats.swift） | 規格指定；CHANGE_06 首頁搬走後沒有人用 |
| `Exercise.homeSummary`（ExerciseHistory.swift） | 規格指定；同上 |
| `ActivityCalendar.dailyCounts`、`ActivityCalendar.level` | 規格指定；只有測試在用 |
| `WorkoutSession.inferredRegion`（Roles.swift） | 掃描：零引用（部位由完成訓練時的 `Region.infer` 算） |
| `Equipment.weightHint`（Enums.swift） | 掃描：零引用 |
| `IntensityTable.defaultStep`（ExerciseStats.swift） | 掃描：只有測試在用；和 `RoundingSteps` 的預設值重複 |
| `Recency.trainingDays` | 掃描：只有測試在用（單邊、爆發次數由 `PlanHistory.sessionCount` 算） |
| `RecentVolume` 的計數、`push`／`pull`／`pullIsShort`、subscript | 掃描：只有測試在用（近 30 天的組數和推拉由 `StatsCache` 算），只留首頁長條的顏色門檻 `RecentVolume.enoughSets` |
| `SetLogic.finish` | 掃描（第二輪）：只有測試在用，完成訓練走 `WorkoutActions.finish`；名稱和它相同，第一輪的掃描被掩護（`8bd7e0f`） |
| `TabBarAutoHide`、`BottomInset`、`TabBarAutoHideModifier`、`TabBarAutoHideLog`、`workoutMiniBarTop` | 第 1 節 |

方法：沒有安裝 Periphery，寫了同等的掃描 `tools/unused_scan.py`（列出 App、共用、小工具裡宣告的型別、函式、屬性、enum case，計算名稱在這三個資料夾出現幾次；`--tests` 另外列出只有測試引用的），再逐一人工確認。這個方法看名稱，不看型別，所以同名的宣告會互相掩護（例如 `RecentVolume` 的 `push` 和角色的 `push`、`SetLogic.finish` 和 `WorkoutActions.finish`）；第二輪另外檢查每個 static 成員有沒有「型別.名稱」或同一個檔案裡的引用（腳本的最後一段），其他的逐一看程式。

**只列出、沒有刪的**（系統、小工具、App Intents、即時動態、反射會用到）：
| 程式 | 為什麼不刪 |
|---|---|
| `LiftLogApp`（`@main`）、`LiftLogWidgetsBundle` | App 和小工具的進入點，由系統呼叫 |
| `LiftLogShortcuts` | App Intents 的 App Shortcut，系統讀取 |
| `BackupError.errorDescription` | `LocalizedError`，錯誤訊息由系統讀取 |
| `placeSubviews`（PlanFlowView 的 Layout） | `Layout` 協定，由 SwiftUI 呼叫 |
| `Theme.tokens` | 只有 `ThemeTests` 在用：用來檢查每個主題都有每個 token（CLAUDE.md 的規定） |
| `LiveActivityLayout.lockScreenHeight` | 即時動態的高度常數，`WidgetSnapshotTests` 用它確認不超過 160 pt |
| 36 個 DEBUG 啟動參數 | 只在 `#if DEBUG`，用來截圖和驗證 |

---

## 4. 第 4-1 節：收鍵盤
- 全 App 收鍵盤的方式：點空白處（`KeyboardDismissOnTap`）、按畫面上的主要按鈕、可捲動的畫面往下拖進鍵盤（系統的 `.scrollDismissesKeyboard(.interactively)`）。鍵盤上方不再有任何列。
- 訓練畫面：UI 測試確認點組與組之間的空隙、說明列（「8 組 × 3 下・休息 45–60 秒」）、動作標題，鍵盤都會收起。動作標題本身是按鈕，點了也會照舊打開動作說明。

---

## 5. 第 4-2 節：候選列沒有辦法融入鍵盤，照規定拿掉
做了一版完整的候選列（commit `c0ac0e7`）：組的數字欄改成 UIKit 的 `UITextField`，`inputAccessoryView` 是 `UIInputView(inputViewStyle: .keyboard)`，5 個候選、點一下填入並跳到下一格、建議重量用強調色加「建議」、最後一格填完收起鍵盤，單元測試和 UI 測試都通過。

但是 iOS 26 的鍵盤是一塊圓角的玻璃面板，`inputAccessoryView` 一律放在面板外面、上方，看起來是分開的一塊。試過四種背景，都一樣：
| 截圖 | 背景 | 結果 |
|---|---|---|
| `V4_candidate_bar_kg_keyboard_style.png`、`V4_candidate_bar_reps_keyboard_style.png` | `UIInputView`，`.keyboard`（規格指定的做法） | 背景是透明的：數字直接浮在訓練畫面上，和組的數字疊在一起 |
| `V4_candidate_bar_default_style.png` | `UIInputView`，`.default` | 一樣透明 |
| `V4_candidate_bar_glass.png` | iOS 26 的玻璃（`UIGlassEffect`） | 變成鍵盤上方另一個膠囊，正是規格要避免的樣子 |
| `V4_candidate_bar_solid.png` | 不透明的底色 | 鍵盤上方另一個長方形，和鍵盤的圓角面板之間有明顯的接縫 |

所以照 §4-2 的規定拿掉候選列（commit `1985585`），沒有自己做鍵盤。組的欄位回到 SwiftUI 的 `TextField`。這一節留下來的是：鍵盤列（-2.5／+2.5／+5、±、下一格、完成）拿掉、全 App 不用 `.keyboard` toolbar、可以記負數的動作（輔助引體向上）的重量欄改用有負號的鍵盤（以前靠鍵盤列的 ±）、點空白處收起鍵盤。實作留在 `c0ac0e7`，之後的 iOS 如果讓附屬視圖融進鍵盤，可以從那裡拿回來。

---

## 6. 自行決定的事項

**§1 分頁列**
1. 最低版本是 iOS 26.0，`tabViewBottomAccessory(isEnabled:)` 要 26.1：26.1 起用系統的參數，26.0 沒有訓練時不加附屬列。
2. 附屬列縮小時（和分頁列同一列）只放「訓練中 0:42」一行，展開時兩行（訓練名稱、經過時間）。
3. `-scrollToBottom` 保留，歷程穩定性的連拍要用；拿掉了它在 `-tabBarLog` 裡的紀錄。
4. UI 測試照模擬器上的系統行為寫：捲回頂端時分頁列恢復（第 2 節）。

**§2 跨日重算**
5. 快照記下計算時的「現在」（`StatsSnapshot.now`），畫面上的「N 天前」、今天的日曆、有氧卡的最後一週、動作詳情頁首的「上次」都用它，和本週、近 30 天同一個時間點；重算時這些一起動。
6. 跨過午夜、時區或系統時間改變時一律重算；回到前景只在日期和上次計算時不同時重算（規格的「同一天回到前景不重算」）。時區改變用每次重新取 `Calendar.current`，不另外記時區。
7. 動作庫分類列的「最久沒練」以前在畫面上算，搬進快照（`neglectedDays`），畫面只讀，也讓 §9 能直接比對。
8. `-fakeNow` 只影響統計快照和用快照時間的畫面；開始訓練、休息計時、完成時間這些記錄用的時間照樣是真的時間，不會把假的時間寫進資料。

**§3 1RM 與舊程式**
9. 主項進步卡「目前」的值是 90 天內最好的估算 1RM；90 天內沒有紀錄的主項照舊不列，只算進「另外 N 個主項」。
10. 「和 4 週前相比」用同一個函式在 4 週前那時候算，90 天內沒有就取全期（以前沒有紀錄時會寫「一樣」）。
11. 只有測試在用的程式也算沒有被引用（App 不會用到），一起刪掉；只為測試存在的檢查（`Theme.tokens`、`lockScreenHeight`）保留。

**§4 鍵盤**
12. 鍵盤列的 ± 拿掉之後，可以記負數的動作的重量欄用 `.numbersAndPunctuation`（有負號）；其他動作照舊是小數鍵盤和數字鍵盤。
13. 候選列先做完整、commit，再依截圖拿掉，讓 git 歷史裡留著可以用的實作。
14. 欄位和打勾加了 UI 測試用的 identifier（「臥推-1-weight」「臥推-1-check」），不影響畫面。

**§5 圖表**
15. `chartDateSelection` 拿掉了「留多久」的參數，全 App 只有一種行為（2 秒）。
16. 動作詳情的折線圖拿掉上面那行（日期與數值、「打開這次訓練」），改成和其他圖表一樣浮在圖上的小標籤（`PeekLabel`）。

**§6 動態島**
17. 新欄位 `dayTypeTitle` 是選填的：更新 App 前已經開始的即時動態照樣解碼，沒有這個欄位時顯示「訓練」。DEBUG 的預覽頁也改成日型簡稱。
18. 示範訓練加了 `-demoWorkoutDayType`、`-demoWorkoutTitle`，V3 用「名稱很長、日型 DE 上肢」的訓練截圖。

**§7 訓練狀態浮窗**
19. 高度＝捲動內容的高度＋標題列；底部的 Home 指示條系統另外加（第一版把它也算進去，下面多了一段空白，`c03f16a` 修正）。量到之前先用半高（只在打開的那一瞬間）。
20. 比螢幕高時用全高、內容捲動；螢幕高度從 window scene 取。往下拖照樣關閉（只有一個 detent，系統的行為）。

**§8 備份**
21. 放進備份的設定：每週目標、只有有氧的訓練也算、重量單位、四個進位、打勾後自動開始休息計時、訓練中顯示即時動態、主題。「休息時間」是每個動作自己的設定，本來就在動作的資料裡。畫面的記憶（歷程的分段、動作庫的排序、訓練頻率的週／月）不是設定，不放。
22. 每週目標沒設定過時寫 null，還原時拿掉目前的設定、回到自動；不認得的單位或主題不寫回。
23. 還原時先寫設定再還原資料，存檔後重算統計就用還原的「只有有氧的訓練也算」。「從 JSON 匯入」和「還原自動備份」都走 `DataMigrations.restore`，兩個都會還原設定。格式版本升到 7。

**§9 真實資料**
24. `-dumpStats` 的 DE 建議重量走真正的 DE 路徑（`SlotAdvice.make`，kg、設定頁的進位）；備份裡沒有設定，乾淨安裝是預設值，腳本也用預設的進位（槓鈴 2.5 kg、其他 1 kg）。
25. 模擬器的時區是 Asia/Taipei，腳本的 `--tz` 預設一樣。
26. 第二個時間點不重新匯入（資料留在第一次匯入的狀態），只換 `-fakeNow`。
27. 比對完馬上把 App 從模擬器移除（連同資料），之後的截圖都是乾淨安裝＋示範資料。`tools/fixtures/` 裡的備份、App 和腳本的輸出都只在這台電腦上。
28. 腳本在終端機只印「一致／不一致」，`--details` 才印兩邊的值（只給本機除錯，這次沒有用到）。說明裡的範例時間用和真實資料無關的日期。

---

## 7. 未解決的事項
- **沒有觸發規則 3**（沒有任何條件連續修 3 次還過不了）。
- 候選列（§4-2）：照規格的退路拿掉，不算未解決，但 G2 的兩項候選列測試和 V4 的「候選列融成一體」因此不適用（第 5 節）。
- 分頁列往上捲不會中途恢復、要捲回頂端（模擬器上的系統行為，第 2 節）：照規格交給系統，沒有加自己的條件；請在實機確認手感。
- 最大字級時，訓練狀態浮窗的「下一次」標記擠成一團（`V2_training_status_largest_text_scrolled.png`）：是原本的版面在 AX5 字級的樣子，不在這次的範圍。
- 開發用的 `-emptyData` 之後再用 `-demoData`，動作沒有輪替順序（「下次主項」顯示「—」）：清空資料後 seed 重新匯入，但輪替順序的一次性旗標還在，所以不會再套用。只影響 DEBUG（這次測試一開始碰到，乾淨安裝就正常），沒有修。
- 開發用的 `-scrollToBottom 分類` 捲到的位置，最後一列在系統分頁列的玻璃後面（`scrollTo(anchor: .bottom)` 沒有算分頁列）。只影響 DEBUG 的捲動，連拍比對照樣全部相同。

---

## 8. 實機確認清單
1. **分頁列縮小的手感**：今天、歷程（紀錄、統計）、動作庫、設定往下捲時分頁列縮小；往上捲時是中途就恢復，還是要回到頂端才恢復（模擬器是後者）；動作詳情頁的分頁列照常顯示。
2. **附屬列的互動**：有進行中的訓練時，橫條在分頁列上方（兩行）、分頁列縮小時和它同一列（一行）；點一下展開訓練；沒有訓練時沒有附屬列；完成或捨棄訓練後消失。
3. **跨午夜重算**：晚上打開 App 停在今天，隔天早上回到 App：「本週」「N 天前」「最久沒練」「下一次」卡、日曆的最後一格都是新的一天；週日晚上到週一早上，本週歸零。
4. **點空白處收鍵盤**：訓練中點組與組之間、說明列、動作標題都會收起；往下拖進鍵盤也會收起；右上角「完成」是結束訓練。
5. **候選列**：這次拿掉了，沒有東西要確認；請看一下鍵盤上方是不是乾淨的，以及輔助引體向上的重量欄有負號可以輸入。
6. **動態島**：有日型的訓練展開時左上角是「DE 上肢」這類簡稱，沒有日型的是「訓練」；鎖定畫面照舊是訓練名稱。
7. **訓練狀態浮窗**：打開就看得到全部、往下拖可以關；把系統字級調大時是全高、可以捲動。
8. **圖表**：每一張圖點一下浮出數字、2 秒後消失；按住拖曳跟著手指、放開 2 秒後消失；動作詳情的折線圖沒有「打開這次訓練」。
9. **備份的設定**：匯出 JSON 後改幾個設定，再匯入同一個檔案，設定要回到匯出時的值；匯入以前的舊備份，設定不變。
10. **主項進步卡**：「和 4 週前相比」的數字用自己的資料看一次是否合理（計算方式改成和換算表同一個估算 1RM）。

---

## 9. 截圖索引（`tools/screens/change11/`）
| 檔名 | 內容 | 標準 |
|---|---|---|
| `V0_today.png` | 乾淨安裝＋示範資料的今天（「下一次」卡、建議主項、日曆、近 30 天） | 一般檢查 |
| `V1_tabbar_expanded.png` | 歷程的統計、有進行中的訓練：分頁列展開，附屬列在上方（兩行） | V1 |
| `V1_tabbar_minimized.png` | 往下捲之後：分頁列縮小，附屬列在同一列（一行「訓練中」） | V1 |
| `V2_training_status.png` | 訓練狀態浮窗，一般字級，高度等於內容 | V2 |
| `V2_training_status_largest_text.png` | 最大字級：全高 | V2 |
| `V2_training_status_largest_text_scrolled.png` | 最大字級捲到最後一列 | V2 |
| `V3_island_de_upper_expanded.png` | 模擬器的動態島展開：名稱很長的訓練，左上角「DE 上肢」 | V3 |
| `V3_island_de_upper_compact.png` | 同一個訓練的動態島縮小 | V3 |
| `V4_kg_keyboard.png` | 訓練中 kg 欄的鍵盤（臥推 DE 主項，說明列有建議重量）：鍵盤上方沒有任何列 | V4 |
| `V4_reps_keyboard.png` | 次數欄的鍵盤：鍵盤上方沒有任何列 | V4 |
| `V4_candidate_bar_kg_keyboard_style.png` | 候選列（`.keyboard` 樣式）kg 欄：透明，數字浮在畫面上 | V4（拿掉的原因） |
| `V4_candidate_bar_reps_keyboard_style.png` | 候選列（`.keyboard` 樣式）次數欄 | V4（拿掉的原因） |
| `V4_candidate_bar_default_style.png` | 候選列（`.default` 樣式）：一樣透明 | V4（拿掉的原因） |
| `V4_candidate_bar_glass.png` | 候選列（玻璃背景）：鍵盤上方另一個膠囊 | V4（拿掉的原因） |
| `V4_candidate_bar_solid.png` | 候選列（不透明背景）：鍵盤上方另一塊長方形 | V4（拿掉的原因） |
| `V5_detail_chart_peek.png` | 臥推的折線圖點一下浮出「7/24・58.4 kg」，沒有「打開這次訓練」 | V5 |
| `stability_<紀錄 records｜統計 stats｜動作庫 library｜分類 category>_1～5.png` | 捲到底部後每 0.5 秒連拍 | 歷程穩定性 |
| `stability_pixel_compare.txt` | 四組都「全部相同」 | 歷程穩定性 |
| `E_today.png` | 空資料的今天 | 空狀態 |
| `E_training_status.png` | 空資料的訓練狀態浮窗（每列「還沒練過」，高度等於內容） | 空狀態、V2 |

---

## 10. commit 列表
```
8bd7e0f CHANGE_11 §3 follow-up: remove SetLogic.finish; the scan checks static members
6e69e9d CHANGE_11 §9 follow-up: neutral example time for -fakeNow
f560224 CHANGE_11 §9: verify the stats against a real backup on the simulator
c03f16a CHANGE_11 §7 follow-up: do not count the bottom safe area twice
7791a69 CHANGE_11 §8: backups carry the settings
1484875 CHANGE_11 §7: the 訓練狀態 sheet is as tall as its content
174ce72 CHANGE_11 §6: the expanded Dynamic Island shows the day type's short name
9ffd08d CHANGE_11 §5: every chart selects the same way
473d1f6 CHANGE_11 §1 follow-up: the tab bar comes back when scrolled back to the top
1985585 CHANGE_11 §4: remove the candidate bar — it does not merge with iOS 26's keyboard
c0ac0e7 CHANGE_11 §4: candidate bar on the keyboard via inputAccessoryView (attempt)
cdaa8d6 CHANGE_11 §3: one estimated 1RM across the app; remove unused code
55bb942 CHANGE_11 §2: recompute the stats snapshot when the date changes
81514a7 CHANGE_11 §1: the tab bar and the workout bar use iOS 26's built-in behavior
```
加上最後一個文件 commit（這份報告、SPEC.md、STATUS.md、截圖）。
