# CHANGE_07 資訊架構重整：最終報告

- 日期：2026-10-26
- 範圍：階段 A～D 全部完成，加上驗收時發現的修正。每個階段都是編譯成功、全部測試通過後才 commit。
- 驗證環境：Xcode（`/Applications/Xcode.app`），iPhone 17 Pro 模擬器（iOS 26），測試一律 `-parallel-testing-enabled NO`。
- 文件：`SPEC.md` 已更新（新增「12. 統計與體重」「13. 開發用啟動參數」「10-1. 資料遷移與自動備份」，改寫今天、開始訓練、歷程、動作庫、設定、備份、深層連結、小工具各節）；`tools/STATUS.md` 已依現況重寫。

---

## 1. 收斂標準結果

### G：建置與測試
| 項目 | 結果 | 證據 |
|---|---|---|
| G1 Debug／Release 建置 0 error 0 warning | **通過** | clean build：Debug（模擬器）、Release（模擬器）、Release（iphoneos，不簽署）、build-for-testing（含測試 target）都是 0 warning、0 error。註：階段 D 的 commit 在測試 target 留了一個 warning（多餘的 `#require`），驗收時發現並在最後的 commit 修掉。 |
| G2 全部測試通過（含 T1～T10） | **通過** | 205 個測試全部通過、0 失敗（31 個測試檔）。 |
| G3 DEBUG 參數與預覽頁都在 `#if DEBUG` 裡 | **通過** | 用腳本檢查所有開發用啟動參數（22 個）的讀取位置都在 `#if DEBUG` 區塊內；`DemoData.swift`、`WidgetGalleryView.swift` 整個檔案包在 `#if DEBUG`。Release 建置會編譯不帶這些程式碼的版本。 |

### T：自動測試
| 項目 | 測試 | 結果 |
|---|---|---|
| T1 輔助重量轉負數與遷移前備份 | `DataMigrationsTests`：assistConversionFilter、migrationBacksUpFirstThenConvertsOnce、nothingToMigrateMeansNoBackup、importingAnOldBackupRerunsTheMigrations | 通過 |
| T2 單一開始入口（繼續／新菜單、只在開始時確認、取消不動） | `WorkoutLauncherTests`：withoutAnActiveWorkoutThePlanOpensDirectly、continueCurrentOpensTheWorkout、cancellingThePlanLeavesTheCurrentWorkoutAlone、confirmingEndsTheCurrentWorkoutStopsTheRestAndStarts、repeatCarriesRolesAndDayType | 通過 |
| T3 上一次只取之前的訓練 | `WorkoutActionsTests.previousSetsInAPastSessionComeOnlyFromEarlierSessions` | 通過 |
| T4 30 天視窗與統計快取 | `StatsCacheTests`：recentWindowIsThirtyCalendarDaysIncludingToday、snapshotCountsOnlySessionsInTheWindow、mainLiftTrend | 通過 |
| T5 動作庫排序與篩選 | `LibraryTests`：fourSorts、sortChoiceIsRemembered、tagFilterIsAnIntersection | 通過 |
| T6 訓練目的名稱與遷移 | `SessionTitleTests`：purposeByDayType、purposeWithoutDayType、legacyAutomaticDetection、migrationRegeneratesAutomaticAndKeepsCustomTitles、restoringAnOldBackupKeepsCustomTitles | 通過 |
| T7 編輯時間 | `SessionTimeEditTests`：movingTheStartShiftsEverything、settingTheEndClampsCompletions、combineKeepsTheTimeOfDay、summaryTimeTextUsesTwentyFourHours | 通過 |
| T8 補登 | `WorkoutLauncherTests.backfillIsAnEndedSessionWithoutRestOrConflict` | 通過 |
| T9 體重 | `BodyWeightLogTests`：savingTheSameDayOverwritesInsteadOfAdding、savingCleansUpOldDuplicatesOnThatDay、perDayKeepsTheLatestRecordOfEachDay、movingAverageUsesTheLastSevenDays、changeComparesWithThirtyDaysAgo、filterByRange | 通過 |
| T10 深層連結與小工具導向 | `DeepLinkTests`：parsesOnlyOurLinks、newAlwaysGoesToThePlanFlow、workoutOpensTheActiveWorkoutOrToday、todayAlwaysGoesToTheTodayTab、routerKeepsOnlyValidLinks、pendingLinkFromTheWidgetIsConsumedOnce、unknownPendingValueIsIgnoredAndCleared、widgetTapTarget、startWorkoutIntentOpensThePlanFlow；`WidgetSnapshotTests.statusAndLink` | 通過 |

### S：程式碼檢查
| 項目 | 結果 | 檢查方式 |
|---|---|---|
| S1 `WorkoutActions.start` 只在 `WorkoutLauncher` 呼叫 | **通過** | App、Shared、小工具裡唯一的呼叫在 `WorkoutLauncher.swift:121`（測試另外直接呼叫）。 |
| S2 右下角＋、開始空白訓練、詳情的開始按鈕都移除 | **通過** | 搜尋 `FloatingActionButton`、「開始空白訓練」、「用這個動作開始訓練」、「加入目前訓練」：0 筆。 |
| S3 「天前」只由 `RelativeDay` 產生 | **通過** | 其他檔案出現的「天前」都在註解裡。體重卡原本寫「比 30 天前」，改成「近 30 天」。 |
| S4 沒有寫死 52／54／56／60 的高度 | **通過** | 搜尋 `height`／`minHeight`／`maxHeight` 為這些數字：0 筆，按鈕走 `Metrics`。 |
| S5 今天的 body 不掃描紀錄 | **通過** | `TodayView` 只讀 `StatsCache`；同檔案的 `CategoryTodoList`（第 2 層）用 `@Query` 讀動作清單，日期和組數一樣從 `StatsCache` 來。 |

### V：截圖驗證（`tools/screens/final/`，seed＋示範訓練；V7 是空資料）
| 項目 | 結果 | 備註 |
|---|---|---|
| V1 今天一個畫面放得下、最後一條長條沒被擋住、沒有橫向捲軸 | **通過** | 有氧那條在分頁列上方，日曆塞滿寬度。 |
| V2 分類待練清單、動作庫第 1 層、分類清單（排序選單打開）、詳情三分頁 | **通過** | 驗收時發現詳情頁的分頁列沒有隱藏，已修（見第 2 節第 34 條）。 |
| V3 設定 5 列 | **通過** | |
| V4 歷程紀錄（月份）、統計 5 張卡 | **通過** | 驗收時修了三處：日期數字帶「日」被擠成兩行、月份標題格式、主項卡列出 90 天沒練的主項。 |
| V5 摘要浮窗（medium）、編輯（時間欄位）、補登第 1 步 | **通過** | 驗收時發現摘要浮窗在 12 小時制地區把 18:30 顯示成 06:30，已修並加測試。 |
| V6 有資料的體重卡、小工具預覽（有＋／訓練中沒有＋） | **通過** | 小工具是 App 內的 DEBUG 預覽頁（同一份畫面程式碼），系統上的實際樣子要在實機確認。 |
| V7 空資料的今天／歷程／動作庫和空狀態文字 | **通過** | 另外截了空資料的統計。 |
| 檢查：沒有被截斷的「…」、沒有重疊、顏色都是主題 token | **通過** | 逐張看過；所有顏色都來自 `Theme.*`。 |

---

## 2. 自行決定

規格沒寫清楚的地方，選擇最不會破壞資料、也最符合設計原則的做法：

**A：遷移與開始入口**
1. 輔助重量轉負數的分界日是 **2026-10-26 00:00（當地時間）**，也就是 CHANGE_06 上線那天。之前的正數改成負數；當天和之後的正數可能真的是加重，不動；0（自重）和負數不動。轉換後動作備註換成新的說明。
2. 雙槓撐還是 assisted 型（輔助重量，越少越好），照指示不動。
3. 遷移沒有要改的資料時不寫自動備份，只記為已執行，避免每次空跑都多一份備份。
4. 自動備份不會自動刪除（檔名到分鐘：`auto-2026-10-26-1333-assistToNegative.json`）。
5. 從「自動備份」還原不會再跑遷移，因為使用者就是要回到遷移前。從檔案匯入**第 5 版以前**的備份會再跑一次遷移（一樣先自動備份），不然舊檔的輔助重量會被當成加重；完成訊息會列出更新了哪些。這一點是驗收時發現的。
6. 已有進行中的訓練時不再提供「加入目前的訓練」，只有「繼續目前訓練／建立新菜單」。`liftlog://new` 和其他開始入口在這時也先問。
7. 結束舊訓練的確認對話框出現在最上層的 sheet 上（建立菜單或摘要浮窗），不跳回底下的畫面。
8. 「不照建議，自由選動作」建立一個沒有日型的訓練，並直接打開「新增動作」。
9. 摘要浮窗的「新紀錄」也只和那次訓練「之前」的紀錄比較（和上一次的規則一致）。

**B：今天、動作庫、設定**

10. 統計（上次日期、次數、近 30 天組數）只算已結束的訓練。30 天 = 今天加前 29 個日曆日。
11. 日曆格子固定 12 pt、間距 3 pt，週數依寬度決定；月份標籤和下個月在 3 週內時省略，避免「5月6月」黏在一起。
12. 「近 30 天」列 9 個分類（含有氧）；CHANGE_06 首頁的推拉比、單邊／爆發次數搬到統計的「平衡」卡，主項紀錄改成統計的「主項進步」卡。
13. 動作庫分類列多寫「M 個未練過」；排序「最久沒練」時沒練過的排最前（和分類待練清單一致）。
14. 篩選主／單／爆可以複選，選多個時都要符合（交集）。
15. 共用高度：按鈕 50、膠囊 38（`Metrics`）。

**C：歷程、摘要、編輯、補登、名稱**

16. 歷程的紀錄不列進行中的訓練（進行中的在訓練中橫條）。
17. 名稱規則的空隙：只有有氧時「有氧」；只有核心或補強（沒有上肢、下肢）時「訓練」；主項是角色為 ME／DE 主項的第一個動作。
18. 使用者輸入的名稱和自動名稱一樣時，不算自訂。
19. 沒有時間資料的舊紀錄按「設定時間」時，預設當天 12:00 開始、長 1 小時。
20. 編輯時結束時間早於（或等於）開始時間時不採用，顯示提示，原本的時間不變。
21. 編輯或補登的訓練不會自動刪除沒打勾的組（只有「完成訓練」時才整理）。
22. 補登預設今天、現在往前 1 小時到現在（不早於今天 0 點）；建立後直接進入編輯，自由選動作時同時打開新增動作。
23. 摘要浮窗的時間固定 24 小時制（「18:30–19:45」）。
24. 從摘要浮窗刪除時，等浮窗關掉才真的刪，避免畫面還在顯示已刪除的資料。

**D：統計、體重、小工具**

25. 主項進步只列 90 天內有紀錄的主項，其他寫「另外 N 個主項 90 天內沒有紀錄」，不然一張卡會有十幾列「—」。
26. 體重卡預設範圍 6 個月。7 日平均 = 那天和前 6 天內的紀錄平均。「近 30 天」的變化是和 30 天前那天或之前最近的一筆相比；最新一筆本身就在 30 天前時不顯示。
27. 同一天只保留一筆：覆蓋時保留原本那筆（更新數字），同一天多出來的舊資料一起刪掉。
28. 從健康 App 帶入：App 裡同一天已經有紀錄的不能選（以 App 內為準）；同一天健康 App 有多筆時取最新的。
29. 健康資料讀取說明加上體重。這是 `project.pbxproj` 裡兩行 `INFOPLIST_KEY_NSHealthShareUsageDescription` 的文字，commit 時只放這兩行，沒有動到你的 `DEVELOPMENT_TEAM` 設定。
30. 完成訓練的「今天體重」是選填；同一天已經有不同數字時先確認覆蓋。
31. 小工具的＋用 `Button(intent: StartWorkoutIntent())`。intent 照設計在 App 的程序執行；萬一系統在小工具的程序執行，那邊會把 `liftlog://new` 存進 App Group，App 回到前景時接手（只接手一次）。
32. 從來沒有紀錄的小型小工具，下方文字改成「按＋建立第一份菜單」；鎖定畫面的圓形小工具仍顯示＋「開始」圖示（不是按鈕，點下去回到今天）。
33. `liftlog://today` 會關掉摘要浮窗和訓練的全螢幕畫面，並清掉今天的導覽路徑。
34. 分頁列自動隱藏在「不隱藏」時改用 `.automatic`，動作詳情才能照設計隱藏分頁列（驗收時發現）。
35. 空資料（`-emptyData`）連動作庫都清空，才能檢查動作庫的空狀態文字。示範資料（`-demoData`）是 5 次有時間、日型、角色和備註的訓練（其中 10/24 和 seed 同一天，用來測「同一天多次」），加 5 筆體重。兩者都只在 DEBUG。

---

## 3. 未解決

- **沒有**觸發規則 3（同一個條件連續修 3 次還過不了）的子功能，沒有恢復任何修改。
- 模擬器做不到、只能在實機確認的項目列在第 4 節。

---

## 4. 實機確認清單

請用 Xcode 裝到手機後確認（裝之前建議先在「設定 → 備份與還原」匯出一份 JSON）：

1. **資料遷移結果**（第一次開啟時自動執行）
   - 「設定 → 備份與還原 → 自動備份」應該有兩份：「輔助重量改記負數」「訓練名稱改成訓練目的」，時間是第一次開啟的時間。
   - 輔助引體向上：10/25 以前的紀錄應該變成負數（例如 −19 kg），圖表和個人紀錄跟著變；10/26 之後記的不動。特別看 10/25 在手機上記的那次。
   - 雙槓撐的數字不變。
   - 歷程的名稱：原本自動產生的（「臥推＋輔助引體向上」這類）變成訓練目的；你自己改過的名稱保留。
2. **小工具的＋**：把小型小工具加到主畫面，按右上角＋應該打開 App 並進入建立菜單；訓練中＋要消失。點小工具其他地方：沒有訓練時回到「今天」分頁第 1 層，訓練中打開那次訓練。鎖定畫面的三種小工具點下去也一樣。
3. **控制中心／動作按鈕／Siri「開始訓練」**：一樣進入建立菜單；訓練中時先問「繼續目前訓練／建立新菜單」。
4. **HealthKit 體重權限**：統計 → 體重卡 → ＋ →「從健康 App 帶入」第一次會要求讀取體重，允許後列出最近 30 天的體重；說明文字應該包含「健康 App 的體重」。
5. **即時動態**：開始訓練、打勾、休息、跳過休息、完成都和以前一樣（這次沒有改即時動態，但開始入口換了）。
6. **手感**：今天一個畫面放得下（實機字級或縮放不同時看會不會被擋住）；第 1 層往下滑分頁列隱藏、動作詳情沒有分頁列；摘要浮窗 medium／large 的拖曳；編輯訓練的時間選擇器。
7. **開始入口**：有進行中的訓練時按「下一次」→ 選「建立新菜單」→ 在建立菜單按取消，原本的訓練要完整保留（沒打勾的組不能被刪）。

---

## 5. 截圖索引（`tools/screens/final/`）

| 檔案 | 內容 | 對應 |
|---|---|---|
| `V1_today.png` | 今天（seed＋示範） | V1 |
| `V2_category_todo.png` | 分類待練清單（核心） | V2 |
| `V2_library.png` | 動作庫第 1 層 | V2 |
| `V2_category_sort_menu.png` | 分類清單＋排序與篩選選單 | V2 |
| `V2_detail_data.png`／`V2_detail_guide.png`／`V2_detail_history.png` | 動作詳情三分頁（臥推） | V2 |
| `V3_settings.png` | 設定 5 列 | V3 |
| `V4_history_records.png` | 歷程紀錄（月份分組） | V4 |
| `V4_history_stats_1.png`／`V4_history_stats_2.png` | 統計 5 張卡（上半／下半） | V4 |
| `V5_summary_medium.png` | 摘要浮窗 medium | V5 |
| `V5_editor_times.png` | 編輯訓練（日期、開始、結束時間） | V5 |
| `V5_backfill_step1.png` | 補登第 1 步 | V5 |
| `V6_weight_card.png` | 有資料的體重卡 | V6 |
| `V6_widget_small.png` | 小型小工具：有＋的三種狀態、訓練中沒有＋ | V6 |
| `V6_widget_lock.png` | 鎖定畫面三種小工具 | V6（補充） |
| `V7_empty_today.png`／`V7_empty_history.png`／`V7_empty_stats.png`／`V7_empty_library.png` | 空資料 | V7 |
| `Extra_auto_backups.png` | 設定 → 備份與還原的自動備份清單 | 執行規則 6 |

---

## 6. 遷移輸出摘要

| 遷移 | 依據 repo 的 seed.json | 清單 |
|---|---|---|
| `assistToNegative` 輔助重量改記負數 | 輔助引體向上 127 組，**119 組轉成負數**，8 組是 0（自重）不動；雙槓撐 70 組不轉換 | `tools/assist_review.txt`（每一次的日期、組數、原值、轉換後） |
| `autoTitles` 訓練名稱改成訓練目的 | 249 次訓練，**249 次重新產生名稱**，0 次視為自訂 | `tools/custom_titles.txt` |

- 模擬器全新安裝的實際執行：兩個遷移都先寫了自動備份（`auto-2026-10-26-1333-assistToNegative.json`、`auto-2026-10-26-1333-autoTitles.json`，各含 68 個動作、249 次訓練、18 筆體重），並出現在設定的自動備份清單（`Extra_auto_backups.png`）。
- 手機上 seed 之後自己記的紀錄，用同樣規則處理，實際數字要在手機上看（第 4 節第 1 項）。兩個清單是用 `tools/migration_review.py` 從 seed 產生的。

---

## 7. 各階段 commit

| 階段 | commit | 內容 |
|---|---|---|
| A | `780e89c` | 遷移與自動備份、輔助重量轉負數、`WorkoutLauncher` 單一入口、移除多餘的開始入口、上一次只取之前的訓練 |
| B | `080fe26` | 今天三區塊與分類待練清單、`StatsCache`、動作庫第 1／2 層與排序篩選、動作詳情精簡、設定 5 列、共用元件 |
| C | `eb8f17f` | 歷程（紀錄｜統計）、摘要浮窗與 ⋯、編輯訓練的時間規則、補登、訓練目的名稱與遷移 |
| D | `0d647b7` | 統計 5 張卡、體重（卡、記錄、HealthKit、摘要與完成畫面）、小工具＋與 `liftlog://today` |
| 驗收修正 | `19c689c` | DEBUG 示範／空資料、空狀態文字、24 小時制、歷程日期與月份、主項卡、分頁列隱藏、舊備份匯入補做遷移 |
| 文件 | 最後一個 commit | SPEC.md、tools/STATUS.md、本報告、截圖，以及測試 target 的 warning 修正 |
