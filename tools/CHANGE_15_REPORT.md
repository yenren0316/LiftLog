# CHANGE_15 標題列、建立菜單合成一個畫面、訓練畫面往下拖縮小、觸覺回饋與新紀錄：最終報告

- 日期：2026-10-29
- 範圍：§0 存原文；§1 今天、歷程、動作庫、設定第 1 層的標題和右上角的按鈕放在同一列（`.inlineLarge`）；§2 建立菜單合成一個畫面（補登也用它）；§3 訓練畫面改成可以往下拖縮小的 sheet；§4 觸覺一律 `.sensoryFeedback`、新紀錄改成估算 1RM（共用的 `NewRecords.find`）。照 prompt 的順序，每一節各自 commit，都是建置成功、全部測試通過後才 commit。CLAUDE.md 的執行規則 1～7 照常適用（這次沒有資料遷移，資料模型和備份格式都沒有改）。
- 結果摘要：**四節都完成，第 1～3 節都沒有遇到「先停下來」的情況**。標題和按鈕同一列之後首頁多出 52 pt（沒有訓練時本週卡底部離分頁列 169.5 pt，有附屬列時 135.5 pt）。訓練畫面改成 sheet 之後，附屬列、即時動態、鍵盤的 UI 測試都通過。R1 真實資料比對兩個時間點全部一致（包括新增的「每一次訓練的新紀錄」）。
- 驗證環境：Xcode 27.1（`/Applications/Xcode.app`），iPhone 17 Pro 模擬器（iOS 26.5），測試一律 `-parallel-testing-enabled NO`。最後的全部測試和截圖在乾淨安裝後用 seed＋示範訓練（`-demoData`），空資料（`-emptyData`）放在最後。真實資料只在 R1 比對時匯入，比對完就把 App 從模擬器移除，之後才跑最後的測試和截圖。
- 文件：`CLAUDE.md`（設計原則加上第 1 層的標題、建立菜單一個畫面、訓練畫面是 sheet；共用做法加上 `PlanMenu`、`NewRecords.find`、觸覺一律 `.sensoryFeedback`）、`SPEC.md`（開頭摘要、分頁列、點擊提示、觸覺、今天、建立菜單（整節改寫）、訓練中畫面、休息計時器、完成訓練與新紀錄、歷程、補登、動作庫、設定、深層連結、開發用參數、已移除）、`tools/STATUS.md`、`tools/changes/README.md`（加上 CHANGE_15）已更新；`tools/CHANGE_12_REPORT.md`（§2 維持 fullScreenCover）、`tools/CHANGE_13_REPORT.md`（`.large` 的大標題）、`tools/CHANGE_14_REPORT.md`（完成畫面照舊全螢幕、補登的入口）、`tools/CHANGE_07_REPORT.md`（自行決定 9 新紀錄、22 補登）加了粗體註記。

---

## 1. 收斂標準的結果

### 建置與測試
| 項目 | 結果 | 驗證方式 |
|---|---|---|
| G1 Debug、Release 0 error 0 warning | **通過** | 最後的程式（`8563e86`）clean build 三種：Debug（含單元測試和 UI 測試 target，`build-for-testing`）、Release 模擬器（`generic/platform=iOS Simulator`）、Release 實機（`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO`），`grep -c 'error:'`、`grep -c 'warning:'` 都是 0。 |
| G2 全部測試通過 | **通過** | 最後的程式乾淨安裝後跑全部測試：**302 個全部通過**、0 失敗。單元測試 261（40 檔）＋UI 測試 41（16 檔＋共用）。CHANGE_14 結束時 281 個：單元新增 13（`PlanMenuTests` 4、`NewRecordsTests` 7、`SessionTimeEditTests` 1、`WorkoutLauncherTests` 1）、刪掉 3（舊的新紀錄判斷）；UI 新增 11（`TitleBarUITests` 4、`PlanSheetUITests` 4、`WorkoutSheetUITests` 2、`NewRecordUITests` 1）。每一節 commit 前的全部測試：§1 285、§2 295、§3 297、§4 302，都是 0 失敗。 |

G2 要求的新測試：

| 規格要求 | 測試 | 結果 |
|---|---|---|
| 建立菜單：照建議直接開始時，建立的訓練和舊流程照建議建立的完全相同（四個日型 × 動作數 1／2／3 × 有沒有跑步機） | `PlanMenuTests.startingAsSuggestedBuildsTheSameWorkoutAsTheOldFlow`：資料是 seed＋動作庫 v2 的輪替＋四次有日型的訓練。24 種組合都從預設答案開始，用日型、動作數、跑步機三個控制改成那一組、不換任何一格；和照 CHANGE_14 `PlanFlowView.start` 寫的舊流程（第一步選答案、「下一步」清空選擇、第二步全部用建議）比較：每個動作、角色、順序相同；兩邊各建立一次訓練，日型、每個動作的格子、組數和組的種類、預設參數、建議重量（`SlotAdvice`）都相同。24 種涵蓋所有 8 種格子（包括主項是爆發划船時的「推」和跑步機）。另外打開不改任何答案時就是「下一次」卡的預設答案，直接開始也相同 | 通過 |
| 建立菜單：改日型時全部重算；改動作數、跑步機時保留手動換過的格子 | `dayTypeRecomputesEverySlotWhileCountAndCardioKeepManualPicks`：換了下肢輔助和核心之後，加跑步機兩格都保留；動作數改成 2，核心那一格不在了、換過的丟掉，下肢輔助保留；改回 3，核心回到建議；改日型後換過的全部不留，結果和沒有換過的一樣。`swappingTheMainRebuildsThePullOrPushSlot`：DE 上肢主項是爆發划船時「推」，換成臥推後「推」不在了（換過的丟掉）、變回「拉」重新計算，補強保留 | 通過 |
| 補登：用同一個畫面，完成後切到歷程的摘要頁並打開編輯 | 單元：`WorkoutLauncherTests.backfillFromThePlanScreenOpensTheSummaryEditor`（從歷程打開建立菜單的畫面、帶著預設時間；「補登這次訓練」建立已結束的訓練、不問進行中的訓練；sheet 關掉後切到歷程、路徑是那次的摘要頁、直接進入編輯）。UI：`PlanSheetUITests.testBackfillUsesThePlanScreen`（歷程 ⋯ →「補登訓練」打開同一個畫面：導覽列「補登訓練」、最上面三個日期時間、格子；按鈕是「補登這次訓練」；按下後打開「編輯訓練」，「完成」下面是歷程推入的「訓練摘要」；最後刪掉這次補登回到歷程） | 通過 |
| 新紀錄：高於之前最好的才算；相等不算；以前沒有紀錄不算；熱身組和超過 10 下不算；一次訓練有好幾個動作刷新時全部列出 | `NewRecordsTests`：`onlyAboveThePreviousBestCounts`（100 × 4 高於之前的 110 才算，95 × 3 不算）、`equalIsNotARecord`（一樣的組；90 × 10 和 100 × 6 都是 120，兩個方向都不算）、`noEarlierRecordIsNotARecord`（沒有紀錄、以前只有熱身、超過 10 下、沒打勾的組都不算）、`warmupsAndMoreThanTenRepsDoNotCount`（這次的熱身、12 下、沒打勾不算；以前的熱身和 15 下不算進「之前最好」；MAX 組和 10 下算）、`everyExerciseThatBeatsItsBestIsListed`（四個動作裡兩個刷新，照順序全部列出）、`onlyWeightExercisesHaveAnEstimatedMax`（輔助型、自重型、負的重量不算）、`sessionsCompareOnlyWithEarlierSessions`（SwiftData：第一次沒有紀錄不算；中間那次和之前比、之後的不影響；最後一次低於中間那次不算） | 通過 |
| UI：「開始」→ 建立菜單 →「開始訓練」兩下就開始訓練 | `PlanSheetUITests.testStartingAWorkoutTakesTwoTaps`：點「下一次」卡的「開始」，直接看到排好的格子和「開始訓練」；按「開始訓練」打開訓練畫面（有經過時間） | 通過 |
| UI：點一格換候選，那一格換掉、其他格不變 | `testPickingACandidateReplacesOnlyThatSlot`：點下肢輔助，出現系統的 Menu（2～5 個候選，第一個打勾而且是這一格目前的動作，截圖 V4）；選第 2 個，那一格換成它、不再寫「建議」，其他三格的內容（無障礙標籤）完全不變；左上角的關閉關掉畫面 | 通過 |
| UI：訓練畫面往下拖會縮小到橫條、訓練繼續；完成畫面往下拖不會關閉 | `WorkoutSheetUITests.testDraggingTheWorkoutDownCollapsesItToTheBar`：拖到一半停住再放開，訓練畫面彈回；從上面往下拖到底，縮小成附屬列的橫條、訓練畫面關掉，「下一次」卡是「進行中」；2 秒後點橫條再打開，經過時間有往前走。`testTheFinishScreenCannotBeDraggedAway`：完成畫面往下拖兩次還在、可以點；按「完成」才關閉 | 通過 |
| UI：首頁在沒有訓練、有進行中的訓練時都一個畫面放得下 | `TodayLayoutUITests` 兩個測試：兩張卡都在導覽列下面、本週卡整張在分頁列（或附屬列）上方，量到的數字存成附件 | 通過（169.5 pt、135.5 pt，見第 2 節） |

另外新增的測試：
- `TitleBarUITests` 4 個（§1）：今天、歷程、動作庫、設定各自啟動，量導覽列裡標題和按鈕的位置：垂直中心差不到 12 pt、標題不蓋到按鈕（實測中心差 0 pt）；歷程的分段、動作庫的搜尋列在標題下方；歷程和動作庫捲下去時標題和按鈕還在同一列，捲回最上面標題回到原位（差不到 2 pt）。
- `NewRecordUITests`（§4）：示範訓練的臥推第 1 組填 200 kg × 3、打勾、完成：完成畫面最上方（「訓練完成」上面）有「新紀錄」區塊，寫著臥推、「估算 1RM 220 kg」和「之前」；歷程的摘要頁臥推旁邊有獎盃；最後刪掉這次訓練。
- `SessionTimeEditTests.backfillDefaultsToTheLastHourOfToday`（補登的預設時間）。

改寫或刪掉的測試：
- `SetLogicTests.newRecordForWeight`、`newRecordForAssistedIsLowerAssistance`、`LogTypeAndUnitTests.bestForNewTypes`：舊的新紀錄判斷（最重的組、輔助重量創新低）隨程式刪掉，換成 `NewRecordsTests`。
- `PlanTests.previewSlotsFollowTheSuggestedMain` 改名 `slotsFollowTheSuggestedMain`：第一步的「今天的順序」預覽刪掉了，測的內容（主項是爆發划船時格子是「推」）不變。
- `WorkoutBarUITests`、`TodayLayoutUITests`、`TabBarMinimizeUITests`：只改註解（全螢幕 → 訓練畫面），行為的測試照舊通過。

### 程式碼檢查
| 項目 | 結果 | 檢查方式 |
|---|---|---|
| S1 舊的建立菜單分步畫面已刪除，沒有殘留 | **通過** | `PlanFlowView.swift` 刪掉；`grep` `QuestionsStep`、`ExercisesStep`、`SlotCard`、`FlowSlots`、`WrapLayout`、`BackfillSheet`、`PlanFlowView`、`planStep`、「下一步」：程式裡 0 筆（只剩 `PlanMenuTests` 說明舊流程的註解）。`PlanBuilder.swift` 裡「第一步／第二步／第三步」的段落標題改成「三個答案／格子／候選動作」。 |
| S2 建議、候選、預設值沒有新的計算，全部來自原本的函式 | **通過** | `PlanMenu` 只呼叫 `PlanDefaults.answers`（打開時的預設答案）和 `PlanRanking.resolve`（格子、候選、選定的動作），自己只決定保留哪些手動選擇；畫面的處方是 `SlotAdvice.make` 的結果（`SlotAdvice.line` 只把組數次數和建議重量接成一行）；候選的小字是 `RankedCandidates.reason`（第一個）和 `PlanCandidate.daysSince`（其他）。開始時的動作和角色走 `WorkoutLauncher.Request.plan`、`WorkoutLauncher.start`。測試見 G2 第一列。 |
| S3 訓練畫面不再使用 fullScreenCover | **通過** | `grep fullScreenCover`：只剩訓練摘要頁打開「編輯訓練」（`SessionEditorView`，第 3 層的編輯，不是訓練畫面）。訓練畫面和完成畫面是 RootView 的 `.sheet` ＋ `.presentationDetents([.large])` ＋ `.interactiveDismissDisabled(coordinator.summary != nil)`。 |
| S4 新紀錄的判斷只有一個共用函式 | **通過** | `NewRecords.find`（`Logic/NewRecords.swift`）；呼叫的地方：完成畫面（`WorkoutSummary.init`）、訓練摘要頁（`WorkoutSummaryPage`）、R1 的 `-dumpStats`。舊的 `SetLogic.isNewRecord`／`best`／`metric`／`lowerIsBetter` 刪掉，`grep isNewRecord(` 0 筆。估算 1RM 用 `PersonalRecords.best1RM`，和 `estimated1RM` 共用 `countsForEstimate`、`epley`。 |
| S5 觸覺都用 .sensoryFeedback，沒有直接呼叫 UIFeedbackGenerator | **通過** | `grep FeedbackGenerator`：0 筆。`.sensoryFeedback` 共 7 處，列在第 3 節。休息倒數本來就是 `.sensoryFeedback(.success)`，不用改。 |
| S6 新增的 DEBUG 參數都在 #if DEBUG 裡 | **通過** | 這次沒有新增參數（`-planStep` 刪掉）。腳本列出所有 `UserDefaults.standard`／`defaults` 的 `.bool|string|integer|double|object(forKey: "字面值")`：44 處，全部在 `#if DEBUG` 區塊內（`PlanSheet` 的 `-planAnswers`、`HistoryView` 的 `-openBackfill` 也是）。 |

另外：舊的分步畫面刪掉後 `AccentChip`（「下一次」標記也用）搬到 `Theme/Components.swift`、`CandidateRow`（換動作用）搬到 `ReplaceExerciseSheet.swift`，沒有留下沒有引用的程式。

### 畫面驗證（`tools/screens/change15/`）
| 項目 | 結果 | 說明 |
|---|---|---|
| V1 今天、歷程、動作庫、設定第 1 層：標題和按鈕在同一列 | **通過** | `V1_today.png`、`V1_history.png`、`V1_library.png`、`V1_settings.png`（UI 測試截取）：大字的標題靠左、齒輪／⋯／＋／關閉在右邊同一列，沒有截斷；歷程的「紀錄｜統計」和動作庫的搜尋列在標題下面。`V1_history_scrolled.png`、`V1_library_scrolled.png`：捲下去時標題留在原位、內容從標題下面捲過去（系統的邊緣模糊）。 |
| V2 首頁比 CHANGE_14 多出來的空間 | **通過** | `V2_today_idle.png`、`V2_today_active.png`（UI 測試截取），數字見第 2 節：兩種狀態都多出 **52 pt**。 |
| V3 建立菜單：四個日型各一張 | **通過** | `V3_plan_meLower.png`、`V3_plan_meUpper.png`、`V3_plan_deLower.png`、`V3_plan_deUpper.png`（UI 測試用日型的 Menu 切換後截取）：主項格跟著日型（ME 主項的「設好安全槓」、DE 爆發的「速度掉了就停」），下肢日是下肢輔助和核心、上肢日是拉和補強。 |
| V4 點一格後的候選 Menu | **通過** | `V4_candidate_menu.png`：系統的 Menu，5 個候選，第一個打勾、小字「建議・主項是膝主導，換髖主導・單邊」（兩行），其他是「111 天前」這類幾天前。原因放得下，沒有改用候選清單頁。`V4_after_pick.png`：選第 2 個之後那一格換掉、寫幾天前，其他格不變。 |
| V5 補登用的建立菜單畫面 | **通過** | `V5_backfill_plan.png`：導覽列「補登訓練」，最上面日期、開始時間、結束時間和說明，下面和建立菜單一樣，主要按鈕「補登這次訓練」。`V5_backfill_editor.png`：補登後直接打開「編輯訓練」。 |
| V6 訓練畫面往下拖到一半時的樣子 | **通過** | `V6_drag_half.png`：錄影（`simctl io recordVideo`）裡 UI 測試拖到一半停住的那一格：訓練畫面的 sheet 往下移到畫面一半左右，後面是變暗的「今天」（iOS 26 的全高 sheet 後面的畫面不縮小）。`V6_released_halfway.png`：放開後彈回；`V6_collapsed_to_bar.png`：拖到底縮小成附屬列的橫條。 |
| V7 完成畫面的「新紀錄」區塊、摘要頁上的 trophy 圖示 | **通過** | `V7_finish_new_record.png`：最上方「新紀錄」區塊（獎盃、臥推、「估算 1RM 220 kg」、小字「之前 93.5 kg」），下面是「訓練完成」，臥推那一列旁邊也有小獎盃。`V7_summary_trophy.png`：歷程的訓練摘要頁，臥推名稱旁的小獎盃。（示範資料，220 kg 是測試填的。） |
| （每輪重跑）歷程穩定性 | **通過** | 紀錄、統計、動作庫第 1 層、分類清單（核心）各 0.5 秒連拍 5 張，遮掉最上面 200 px 比對都「全部相同」（`stability_pixel_compare.txt`）。 |

截圖逐張看過：沒有不該有的截斷或重疊，顏色都是主題 token 或系統的部位色，首頁一個畫面放得下。空資料（`E_today.png`、`E_library.png`、`E_plan.png`）：首頁「ME 下肢」「主項：—」「3 個動作」；動作庫是說明文字和 9 個「0 個動作」；建立菜單每一格都是「沒有符合的動作，這一格會略過」、「開始訓練」不能按，「不照建議，自由選動作」可以用。

### 真實資料（R1）
做法：照 CHANGE_11 §9。乾淨安裝後用 `-importBackup tools/fixtures/real_backup.json -fakeNow <時間點 1> -dumpStats tools/fixtures/app_1.json` 啟動一次，再用時間點 2 啟動一次（不重新匯入）。兩個時間點由腳本從備份算出（備份最後一筆訓練的隔天中午、之後第一個週一 00:05），只寫在 `tools/fixtures/times.json`。`tools/verify_real_data.py` 直接讀備份 JSON、照 SPEC.md 的規則自己算一次，逐項比對；這次加上第 4 節的新紀錄：每一次已結束的訓練裡被判斷為新紀錄的動作（App 輸出 `NewRecords.find(in:)` 的結果，腳本照第 4 節的定義自己算：Epley、1～10 下、有重量的已完成正式組和 MAX 組、大於 0、只有重量型、和開始時間更早的訓練比、相等不算），每一次訓練都比（有刷新和沒刷新的訓練都有）。比對完把 App 從模擬器移除，之後的測試和截圖都是乾淨安裝＋示範資料。真實資料和所有輸出都只在 `tools/fixtures/`（在 .gitignore 裡，從來沒有 commit）。

| 項目 | 時間點 1 | 時間點 2 |
|---|---|---|
| 本週天數、組數（下肢、上肢、其他）、有氧分鐘 | 一致 | 一致 |
| 上週同期 | 一致 | 一致 |
| 本週卡的天數 | 一致 | 一致 |
| 本週卡的組數 | 一致 | 一致 |
| 日曆的週數 | 一致 | 一致 |
| 日曆顯示的每一天的部位 | 一致 | 一致 |
| 本週卡的輪替膠囊 | 一致 | 一致 |
| 本週卡的提醒（分類和天數） | 一致 | 一致 |
| 平衡卡 9 個分類的組數（近 30 天） | 一致 | 一致 |
| 推拉比、單邊次數、爆發次數 | 一致 | 一致 |
| 日型（上次日期、幾天前、上次主項、下次主項） | 一致 | 一致 |
| 「下一次」的日型 | 一致 | 一致 |
| 主動作的估算 1RM 與 60% 建議重量 | 一致 | 一致 |
| **歷史上每一次訓練的新紀錄（動作）**（新增） | 一致 | 一致 |

---

## 2. 第 1～3 節有沒有遇到「先停下來」的情況：都沒有

### §1 標題列：沒有
`.toolbarTitleDisplayMode(.inlineLarge)` 在 iOS 26.5 上：大字的標題和右上角的按鈕垂直置中在同一列（`TitleBarUITests` 量到中心差 0 pt），標題完整、不蓋到按鈕；捲動時標題留在原位（`inlineLarge` 不會縮成小標題），內容從標題和搜尋列下面捲過去，邊緣是系統的模糊效果；捲回最上面標題回到原位。三種「先停下來」的情況（截斷、對不齊、捲動時樣子不對）都沒有。

第 2 層以下：每一頁本來就明確寫了 `.inline`，不會沿用上一層的 `inlineLarge`，維持原樣。

首頁多出來的空間（`TodayLayoutUITests`，iPhone 17 Pro 模擬器、示範資料）：

| 狀態 | 導覽列底部 | 下一次卡 | 本週卡 | 下緣 | 空隙 | CHANGE_14 | 多出 |
|---|---|---|---|---|---|---|---|
| 沒有訓練 | 116 pt | 115.5–312.2 pt | 323.2–621.5 pt | 分頁列 791 pt | **169.5 pt** | 117.5 pt | **+52 pt** |
| 有進行中的訓練（附屬列顯示） | 116 pt | 115.5–290.2 pt | 301.2–599.5 pt | 附屬列 735 pt | **135.5 pt** | 83.5 pt | **+52 pt** |

（導覽列底部從 168 pt 變成 116 pt：以前標題下面那一列 52 pt 不見了。）

觀察（照規格交給系統，沒有改）：動作庫的搜尋列下面到第一個分區有 List 預設的上方間距（離導覽列 35 pt），標題和按鈕同一列之後看起來比以前空一點；內容本身仍然比以前往上了 17 pt。

### §2 建立菜單：候選的原因放得下 Menu，不需要改成候選清單頁
系統 Menu 的每個項目是兩行：名稱、小字。建議的小字最長是「建議・主項是膝主導，換髖主導・單邊」這類，在 Menu 裡換成兩行，完整顯示（`V4_candidate_menu.png`）。一開始用 `Label` 包住名稱和小字來放打勾，系統會把小字丟掉；改成 Button 的 label 直接放兩個 Text 和打勾的 Image，三樣都會顯示。

### §3 訓練畫面改成 sheet：沒有衝突
- 附屬列：往下拖或收合之後回到附屬列的橫條，點橫條再打開（`WorkoutBarUITests`、`WorkoutSheetUITests`）；`TodayLayoutUITests` 的附屬列狀態照樣放得下。
- 即時動態：開始、結束和內容都看資料（`LiveActivityController`），和訓練畫面怎麼呈現無關；`DynamicIslandUITests`、`TimerTextUITests`（附屬列和訓練畫面的經過時間、休息倒數的 ±15 和跳過）都通過。
- 鍵盤：`KeyboardUITests.testWorkoutFieldsDismiss`（訓練畫面的重量欄打開鍵盤、點空白處收起、往下拖收起）通過。
- 「完成」「捨棄訓練」：`DiscardWorkoutUITests`、`NewRecordUITests`（完成 → 刪除未完成的組 → 完成畫面 →「完成」）通過。
- 完成畫面：`.interactiveDismissDisabled`，往下拖不會關閉（`WorkoutSheetUITests`）。

所以維持 sheet，沒有退回 fullScreenCover。

---

## 3. 第 4 節：觸覺一覽
| 時機 | 觸覺 | 位置 |
|---|---|---|
| 打勾完成一組（取消打勾不震） | `.impact(weight: .light)` | `SetRow`（訓練中、編輯訓練共用） |
| 組的欄位不齊全、該列晃動 | `.error`（CHANGE_10 就有，照舊） | `SetRow` |
| 完成訓練（完成畫面出現；有新紀錄時獎盃同時彈） | `.success` | `WorkoutSummaryView` |
| 建立菜單換日型 | `.selection` | `PlanSheet` |
| 建立菜單換候選 | `.selection` | `PlanSheet` |
| 建立菜單改動作數 | `.selection` | `PlanSheet` |
| 休息倒數結束 | `.success`（本來就是 `.sensoryFeedback`，維持） | `WorkoutView` |

強度都交給系統（沒有自訂強度），系統關掉震動時不震。

新紀錄（`NewRecords.find`）：
- 定義：這次訓練中某個動作最好的估算 1RM（`PersonalRecords.best1RM`：Epley，只算 1～10 下、有重量的已完成正式組和 MAX 組，大於 0），高於這次訓練開始之前（開始時間更早的訓練）這個動作所有紀錄最好的估算 1RM；以前沒有可以計算的紀錄不算；相等（1e-6 以內）不算；只有重量型的動作。
- 完成畫面：最上方「新紀錄」區塊（`trophy.fill`、每個刷新的動作的名稱、新的估算 1RM、之前最好的），獎盃 `.symbolEffect(.bounce)` 在畫面出現時彈一次、同時 success 觸覺；「減少動態效果」開啟時不彈（觸覺照樣）。
- 訓練摘要頁：刷新紀錄的動作名稱旁一個小的 `trophy.fill`（無障礙標籤「新紀錄」）。

---

## 4. 刪掉的程式
| 程式 | 原因 |
|---|---|
| `Views/Plan/PlanFlowView.swift` 整個檔案：`PlanFlowView`、`QuestionsStep`（三個問題）、`FlowSlots`（今天的順序預覽）、`WrapLayout`、`ExercisesStep`（選動作）、`SlotCard` | §2：換成一個畫面的 `PlanSheet`（`Views/Plan/PlanSheet.swift`）和狀態 `PlanMenu`（`Logic/PlanMenu.swift`） |
| `-planStep`（直接跳到第二步） | §2：沒有第二步了 |
| `BackfillSheet` 和 `HistoryView` 的 `showingBackfill`、`pendingBackfill`、`continueBackfill` | §2：補登用建立菜單的畫面，時間在畫面最上面 |
| `CandidateRow` 的單選圈（`isSelected` 參數） | §2：只有舊的第二步在用；換動作沒有單選圈 |
| 訓練畫面的 `fullScreenCover`（`RootView`） | §3：換成全高的 sheet |
| `SetLogic.isNewRecord`、`SetLogic.best`、`SetLogic.metric`、`SetLogic.lowerIsBetter` | §4：舊的新紀錄判斷（最重的組、輔助重量創新低），換成 `NewRecords.find` |
| `WorkoutSummaryPage.isNewRecord`、`WorkoutSummary.init` 裡各自的新紀錄判斷 | §4：都改呼叫 `NewRecords.find` |
| `SetLogicTests.newRecordForWeight`、`newRecordForAssistedIsLowerAssistance`、`LogTypeAndUnitTests.bestForNewTypes` | §4：測的是刪掉的程式 |
| 完成畫面中間的「新紀錄」卡（舊的，只列名稱和組） | §4：換成最上方的「新紀錄」區塊（新舊估算 1RM） |

搬家（沒有刪）：`AccentChip` → `Theme/Components.swift`；`CandidateRow` → `Views/Workout/ReplaceExerciseSheet.swift`；`PlanRequest` → `PlanSheet.swift`。

---

## 5. 自行決定的事項

**順序與 commit**
1. 照 prompt 的順序 §1 → §2 → §3 → §4。§1 的全部測試在跑的時候已經開始寫 §2：`HistoryView` 同時有兩節的修改，§1 的 commit 用 `git hash-object`／`update-index` 只放進 §1 那兩行（commit 的內容就是那次測過的那一份）；§3、§4 的程式先放在暫存的資料夾，前一節的測試通過、commit 之後才放進工作區，所以每個 commit 都是測過的那一份。

**§1 標題列**
2. 只改四個第 1 層（今天、歷程、動作庫、設定的 sheet）；第 2 層以下每一頁本來就明確寫 `.inline`，沒有動。
3. 動作庫的搜尋列下面的空間是 List 預設的上方間距，照「交給系統」沒有調。
4. `TitleBarUITests` 每個畫面各自啟動：捲動會讓分頁列縮小（只剩目前的分頁），用分頁列切換會找不到按鈕。

**§2 建立菜單**
5. 呈現方式沿用 RootView 的 sheet；導覽列是 inline 的「建立菜單」（補登時「補登訓練」），左上角系統的關閉按鈕（取代以前的「取消」）。
6. 「換日型」是大字日型右邊的膠囊（系統的 Menu），照規格只列其他三個日型，依輪替順序。
7. 動作數的分段寫「1 個」「2 個」「3 個」，寬 150 pt，跑步機的開關文字「跑步機 30 分鐘」一行放得下（字級很大時最多縮到 80%）。
8. 處方一行＝預設參數的組數次數（`Prescription.volume`）＋建議重量（「建議 32.5 kg（60%）」「上次 100 kg」「用能做得很快的重量」），照規格的例子不放休息時間；ME 和 DE（爆）的安全提示照舊另一行（warning 的三角形圖示）。
9. 候選 Menu 的小字：第一個是「建議・原因」（原本的 `RankedCandidates.reason`）；原本的函式只給第一個原因，其他候選不另外算原因（S2），用已經有的「幾天前」（`PlanCandidate.daysSince`：「12 天前」「還沒練過」）。
10. 目前選的候選在 Menu 裡打勾（系統的選單項目圖示）。
11. 換過的格子：原因那一行改成那個動作的幾天前（中性色），不再寫 accent 的「建議」（它不是建議）。
12. 有氧那一格固定跑步機（只有一個候選），不能點、沒有 Menu、沒有「›」類的箭頭；其他格右邊有 `chevron.up.chevron.down`（系統 Menu 的慣用圖示）。舊的第二步有氧也不能選。
13. 「改動作數、跑步機時保留手動換過、還在的格子」也套用到換某一格本身：主項換成爆發划船時「拉」那一格不在了，換過的「拉」丟掉；換回臥推時「拉」重新計算。
14. 觸覺只在打開之後的改變才震：觸覺掛在畫面內容上，內容出現時已經是預設答案，所以打開時不震。跑步機的開關沒有加 selection（規格沒有列，系統的開關自己有）。
15. 「開始訓練」用 iOS 26 的 `safeAreaBar`：捲到按鈕下面的內容由系統的邊緣效果淡出；以前的 `safeAreaInset` 會讓內容直接從按鈕下面透出來。
16. 補登：原本第 1 步的日期、開始、結束時間合進這個畫面最上面的卡片（連同「補登的訓練是已經結束的訓練…」的說明），預設時間抽成 `SessionTimeEdit.defaultBackfill`（今天、現在往前 1 小時到現在，不跨到前一天，和 CHANGE_07 一樣）；「不照建議，自由選動作」在補登時也是補登（打開新增動作）。結束時間早於開始時寫提醒，兩個按鈕都不會建立訓練。
17. 舊流程的參考：舊的程式刪掉了，測試裡照 CHANGE_14 `PlanFlowView.start` 的寫法重寫一份當參考（第一步選答案 →「下一步」清空選擇 → 每一格用第一個建議 → 依格子順序、角色是格子的角色），和新的畫面的狀態比較，再各建立一次訓練比較內容。
18. `-planAnswers` 保留（四個日型的截圖用 UI 測試切 Menu）；`-openBackfill YES` 改成直接打開補登的建立菜單。

**§3 訓練畫面**
19. `.presentationDetents([.large])`、`.interactiveDismissDisabled(coordinator.summary != nil)` 放在 sheet 的內容上；往下拖由 binding 的 set 把 `isExpanded` 設成 false，和收合按鈕同一條路，所以兩者完全相同。
20. 拖到一半放開時系統把 sheet 彈回（UI 測試確認訓練畫面還在）。
21. 衝突的檢查用現有的 UI 測試（附屬列、計時、動態島、鍵盤、捨棄）加上新的 `WorkoutSheetUITests`，全部通過，所以沒有停下來。

**§4 觸覺與新紀錄**
22. 新紀錄只有重量型的動作：App 裡估算 1RM 只定義在重量型（個人紀錄、換算表、主項進步都是）；輔助型的輔助重量、自重型和計時型的負重套 Epley 沒有意義。以前「輔助重量創新低」「自重最多次數」也算新紀錄，現在不算。
23. 負的重量（輔助引體向上記成 −20 kg）沒有估算 1RM（和 `PersonalRecords.estimated1RM` 一樣只取大於 0），不會有新紀錄。
24. 「相等不算」用 1e-6 kg 的誤差：例如 90 × 10 和 100 × 6 都是 120，浮點數算出來差一點點，兩個方向都不算。
25. 「這次訓練開始之前」＝開始時間嚴格早於這次訓練；完成畫面和摘要頁都一樣，所以舊的訓練摘要看的是那次訓練當時刷新的，之後的紀錄不影響。
26. `PersonalRecords.best1RM`（這些組裡最好的估算 1RM）和 `estimated1RM` 共用 `countsForEstimate`、`epley`；`estimated1RM` 的 90 天規則沒有改。
27. 完成畫面的「新紀錄」區塊放在「訓練完成」上面（規格的「最上方」）；「估算 1RM 220 kg」、小字「之前 93.5 kg」，單位跟著設定；獎盃和數字中性色（CHANGE_13 §3 新紀錄不用強調色）。下面各動作的列，刷新的動作名稱旁也有小獎盃（和摘要頁一樣）。
28. success 觸覺在完成畫面出現時一次；有新紀錄時獎盃同時彈，不另外再震（不會連震兩下）。「減少動態效果」只關掉彈跳，觸覺照樣有。
29. 摘要頁的「新紀錄」文字標籤換成名稱旁的小獎盃（caption 大小、中性色），放在名稱和角色標記之間。
30. 休息倒數結束：CHANGE_06 起就是訓練畫面上的 `.sensoryFeedback(.success, trigger: restTimer.finishedCount)`，維持；訓練畫面收合時不震（和以前一樣，App 在背景時是本機通知）。

**R1**
31. 新紀錄的比對：App 的 `-dumpStats` 輸出每一次已結束訓練的新紀錄動作 id（排序），腳本自己算一次逐次比對；新紀錄不看「現在」，兩個時間點的結果一樣，照規格兩次都比。

**其他**
32. Release 的 clean build 用 `build/g1/` 底下的 derived data（`build/` 在 .gitignore 裡）。

---

## 6. 未解決的事項
- **沒有觸發規則 3**（沒有任何條件連續修 3 次還過不了；每一節的全部測試第一次就通過）。
- 沒有「先停下來」的情況（第 2 節）。
- 觀察到、照規格交給系統：動作庫的搜尋列下面的空間（第 2 節）。
- CHANGE_11 留下的兩個 DEBUG 小問題照舊（`-emptyData` 之後再 `-demoData` 沒有輪替順序、`-scrollToBottom 分類` 最後一列在分頁列後面），只影響開發用的參數。

---

## 7. 實機確認清單
1. **標題列的樣子**：今天、歷程、動作庫、設定的大字標題和右上角的按鈕在同一列、對齊；往下捲時標題留著、內容從下面捲過去的感覺；首頁兩張卡上面的空間。
2. **建立菜單的操作手感**：「開始」之後直接看到菜單，照建議按「開始訓練」；「換日型」的 Menu；動作數的分段、跑步機的開關；點一格的 Menu（5 個候選、小字看不看得清楚、打勾）；換過一格之後改動作數會不會保留；「不照建議，自由選動作」的位置；補登用同一個畫面（最上面的日期和時間）。
3. **往下拖縮小的手感**：從訓練畫面最上面往下拖縮小到「訓練中」橫條；內容捲到中間時往下拖是捲動、不會關掉；鍵盤開著時往下拖；完成畫面拖不掉、要按「完成」。
4. **各種觸覺的強弱**：打勾（輕）、完成訓練（success）、建立菜單換日型、換候選、改動作數（selection）、休息倒數結束；系統關掉震動時都不震。
5. **新紀錄的動畫**：完成畫面最上方的獎盃彈一次，和觸覺同時；開啟「減少動態效果」時不彈；摘要頁的小獎盃。

---

## 8. 截圖索引（`tools/screens/change15/`）
| 檔名 | 內容 | 標準 |
|---|---|---|
| `V1_today.png`、`V1_history.png`、`V1_library.png`、`V1_settings.png` | 四個第 1 層：大字的標題和右上角的按鈕同一列（UI 測試截取） | V1 |
| `V1_history_scrolled.png`、`V1_library_scrolled.png` | 捲下去時標題留在原位 | V1 |
| `V2_today_idle.png`、`V2_today_active.png` | 首頁沒有訓練、有進行中的訓練（UI 測試截取，數字見第 2 節） | V2 |
| `V3_plan_meLower.png`、`V3_plan_meUpper.png`、`V3_plan_deLower.png`、`V3_plan_deUpper.png` | 建立菜單的畫面，四個日型（用日型的 Menu 切換） | V3 |
| `V4_candidate_menu.png` | 點下肢輔助後的候選 Menu | V4 |
| `V4_after_pick.png` | 選了第 2 個候選之後，只有那一格換掉 | V4 |
| `V5_backfill_plan.png` | 補登用的建立菜單畫面（「補登這次訓練」） | V5 |
| `V5_backfill_editor.png` | 補登後直接打開編輯訓練 | V5 |
| `V6_drag_half.png` | 訓練畫面往下拖到一半（錄影的一格） | V6 |
| `V6_released_halfway.png`、`V6_collapsed_to_bar.png` | 拖到一半放開彈回；拖到底縮小成附屬列的橫條 | V6 |
| `V6_finish_after_drag.png` | 完成畫面往下拖之後還在 | V6／§3 |
| `V7_finish_new_record.png` | 完成畫面最上方的「新紀錄」區塊 | V7 |
| `V7_summary_trophy.png` | 訓練摘要頁，臥推旁的小獎盃 | V7 |
| `plan_default.png` | 「開始」之後的建立菜單（預設答案） | §2 |
| `stability_<records｜stats｜library｜category>_1～5.png` | 捲到底部後每 0.5 秒連拍 | 歷程穩定性 |
| `stability_pixel_compare.txt` | 四組都「全部相同」 | 歷程穩定性 |
| `E_today.png`、`E_library.png`、`E_plan.png` | 空資料的首頁、動作庫、建立菜單 | 空狀態 |

---

## 9. commit 列表
```
8563e86 CHANGE_15 §4: system haptics and estimated-1RM new records
7e41e31 CHANGE_15 §3: the workout screen is a sheet you can drag down
aea233f CHANGE_15 §2: the plan is one screen
f6f284b CHANGE_15 §1: title and toolbar button share one row (inlineLarge)
e0e89e6 CHANGE_15 §0: save the prompt
```
加上最後一個文件 commit（這份報告、SPEC.md、CLAUDE.md、STATUS.md、舊報告的註記、截圖）。
