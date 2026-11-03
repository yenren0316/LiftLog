# CHANGE_18 主項的 48 小時規則、新動作的熟悉日、動作數預設與 DE 日的核心：最終報告

- 日期：2026-11-03
- 範圍：
  - §0 存原文。
  - §2 主項的 48 小時規則：輪到的主項在 48 小時內有完成組就換輪替表的下一個；其他格子把 48 小時內練過的排到最後。
  - §3 新動作第一次當 ME 主項是熟悉日。
  - §4 動作數的預設依日型（ME 2 個、DE 3 個），DE 日的第三格是核心。
  - §5 四處同步：「下一次」卡、建立菜單、訓練狀態浮窗、訓練畫面呼叫同一套函式。
  - 每一節各自 commit，都是建置成功、全部測試（單元＋UI）通過後才 commit。CLAUDE.md 的執行規則 1～7 照常適用（這次沒有資料遷移，資料模型和備份格式都沒有改）。
- 結果摘要：
  - **四節都完成，收斂標準全部通過，沒有觸發規則 3。**
  - 規格第 1 節的情境（DE 上肢輪到臥推（速度），但臥推昨天在別的訓練做過）現在建議借力推舉，原因「臥推（速度）昨天練過，換下一個」。單元測試、四處一致的測試和截圖都用這個情境。
  - R1 真實資料兩個時間點全部一致。另外用一份「加了一次自由訓練」的備份副本，讓真實資料也實際跑到 48 小時跳過的分支，也一致（第 2 節）。
- 驗證環境：
  - Xcode 27.2，iPhone 17 Pro 模擬器（iOS 26.5），測試一律 `-parallel-testing-enabled NO`。
  - 最後的全部測試和截圖：乾淨安裝後用 seed＋示範訓練（`-demoData`），空資料（`-emptyData`）放在最後。
  - 真實資料只在 R1 比對時匯入，比對完就把 App 從模擬器移除，之後才跑最後的測試和截圖。
- 文件：
  - `tools/changes/CHANGE_18.md`（原文）、`tools/changes/README.md`
  - `SPEC.md`（開頭摘要、角色系統的預設參數和熟悉日、今天的「下一次」卡、訓練狀態、`StatsCache`、建立菜單（動作數、格子表、候選表、48 小時規則、最久沒做）、訓練中畫面、開發用參數）
  - `tools/STATUS.md`
  - `CLAUDE.md`（共用的做法：候選的最近一次完成組、48 小時規則、熟悉日各只有一個函式）
  - `tools/CHANGE_13_REPORT.md`、`tools/CHANGE_15_REPORT.md`：被這次改掉的條目旁加了粗體註記（ME「做到 3RM」的測試、DE 上肢的第三格、動作數）。
  - 這份報告。

---

## 1. 收斂標準的結果

### 建置與測試
| 項目 | 結果 | 驗證方式 |
|---|---|---|
| G1 Debug、Release 0 error 0 warning | **通過** | 最後的程式（`0e8d08d`）clean build 三種：Debug（含單元測試和 UI 測試 target，`build-for-testing`）、Release 模擬器（`generic/platform=iOS Simulator`）、Release 實機（`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO`），`grep -c 'error:'`、`grep -c 'warning:'` 都是 0。 |
| G2 全部測試通過 | **通過** | 最後的程式乾淨安裝後跑全部測試：**345 個全部通過**、0 失敗。單元測試 299（45 檔）＋UI 測試 46（18 檔＋共用）。CHANGE_17 結束時 321 個：單元新增 22（`RecoveryTests` 12、`FamiliarizationTests` 5、`PlanSyncTests` 4、`PlanMenuTests` 1），UI 新增 2（`PlanRulesUITests`）。每一節 commit 前的全部測試：§2 333、§3 338、§4 339、§5 345，都是 0 失敗。 |

G2 要求的新測試：

| 規格要求 | 測試 | 結果 |
|---|---|---|
| 48 小時：47 小時前做過會跳過、49 小時前不會 | `RecoveryTests.fortyEightHoursIsRealTimeNotCalendarDays`：完成組 47 小時前算、49 小時前不算；剛好 48 小時不算（「小於 48 小時」）。日曆上是前天晚上、但還不到 48 小時的也算。`skipsTheNextMainDoneWithin48Hours`：DE 上肢上次爆發划船，臥推的完成組 47 小時前 → 建議借力推舉；49 小時前 → 照輪替建議臥推，原因照舊「輪替的下一個（上次：爆發划船）」 | 通過 |
| 跳過後選輪替表的下一個；連續兩個都在 48 小時內時再往下 | `skipsTheNextMainDoneWithin48Hours`（跳過臥推 → 借力推舉，候選順序是借力推舉、爆發划船、臥推）；`twoInARowWithin48HoursGoesFurtherDown`：ME 上肢上次窄握臥推，臥推昨天、肩推今天都做過 → 地板臥推，原因「臥推昨天練過、肩推今天練過，換下一個」 | 通過 |
| 池子全部都在 48 小時內時選最久的那個 | `wholePoolWithin48HoursPicksTheOldest`：DE 上肢三個分別在 10、30、40 小時前 → 40 小時前的借力推舉排第一，原因「都在 48 小時內練過，選最久沒練的」 | 通過 |
| 48 小時看的是同一個動作：速度版和一般版一起算；不同日型、不同角色、自由選動作做過的都算 | `sameExerciseAcrossRolesDayTypesAndFreeWorkouts`：臥推在 30 小時前分別以 DE 主項（速度版）、ME 主項（ME 上肢）、推（ME 下肢的訓練）、自由選動作（沒有日型）做過，四種情況 DE 上肢的建議都是借力推舉；反過來，DE 上肢做過速度臥推，ME 上肢的臥推也跳過 | 通過 |
| 跳過後，下一次從實際用的主項往下接 | `afterSkippingTheRotationContinuesFromWhatWasUsed`：跳過臥推、照建議做了借力推舉；三天後（臥推早就超過 48 小時）建議爆發划船，不是補回臥推；再下一次才回到臥推 | 通過 |
| 其他格子的 48 小時排除，以及全部被排除時不排除 | `otherSlotsPutRecentExercisesLast`：上次拉是垂直 → 先水平，但兩個水平拉都在 48 小時內 → 排到最後，建議變成還沒練過的輔助引體向上，排在後面的三個也照原本的順序；下肢輔助：主項深蹲，單腳 RDL 昨天練過 → 建議臀推（原因「主項是膝主導，換髖主導」），單腳 RDL 排最後。`otherSlotsKeepTheOriginalOrderWhenEveryCandidateIsRecent`：核心三個都在 48 小時內 → 照原本的最久沒練優先，`Recovery.deferringRecent` 的結果和原本完全相同 | 通過 |
| 熟悉日：沒有完成組的 ME 主項顯示熟悉日；有完成組之後恢復正常處方；早安式也一樣 | `FamiliarizationTests`：`newMaxEffortMainIsAFamiliarizationDay`（處方「熟悉日：逐步加到順手的 5 下，不衝極限」、「下一次」卡「主項：前蹲舉・熟悉日」、只有沒打勾的組也算新動作；組數、休息、「設好安全槓」照舊）、`anyCompletedSetRestoresTheNormalPrescription`（ME 主項、DE 主項、下肢輔助的完成組都算，恢復「逐步加重到當天 3RM・上次 60 kg」「做到 3RM」）、`goodMorningToo`（早安式：熟悉日 → 有紀錄後「做到 5RM」）、`onlyMaxEffortMains`（DE 速度主項照舊「用能做得很快的重量」，其他角色不是熟悉日）、`workoutCardShowsFamiliarizationUntilTheWorkoutIsDone`（SwiftData：訓練畫面的說明列是熟悉日，這次訓練裡打勾了也還是；完成後算用過這個主項（`Rotation.lastMainID`）；下一次的訓練恢復「逐步加重到當天 3RM・充分休息」） | 通過 |
| 動作數預設：ME 日 2 個、DE 日 3 個；跑步機沿用上次 | `PlanTests.countDefaultsByDayTypeAndCardioFromLastSession`：四個日型 2、2、3、3；上次 ME 上肢 3 個＋跑步機 → DE 下肢 3 個、跑步機；上次 DE 上肢只做 1 個 → ME 下肢還是 2 個；上次 ME 下肢 3 個 → ME 上肢 2 個；上次只做有氧 → 跑步機看上一次訓練。`PlanMenuTests.countFollowsTheDayTypeUntilChangedByHand`：打開時 ME 下肢 2 個；換成 DE 上肢 3 個、ME 上肢 2 個；手動改成 3 之後換日型都保留 3。`WidgetSnapshotTests`：小工具的建議動作數一樣 | 通過 |
| 第三格：DE 上肢、DE 下肢都是核心；ME 下肢是核心、ME 上肢是補強 | `PlanTests.slotsByDayTypeAndCount`：DE 上肢 3 →主項、拉、核心；DE 下肢 3 → 主項、下肢輔助、核心；ME 下肢 3 → 主項、下肢輔助、核心；ME 上肢 3 → 主項、拉、補強；主項是拉的 DE 上肢 3 → 主項、推、核心。`scenario7PowerRowAsMainTurnsPullIntoPush`、`PlanMenuTests.swappingTheMainRebuildsThePullOrPushSlot` 也改成核心 | 通過 |
| 「下一次」卡、建立菜單、訓練狀態浮窗、訓練畫面四處的主項和處方一致 | `PlanSyncTests` 四個（SwiftData：seed＋動作庫 v2＋幾次訓練）。每個日型各一個情境：DE 上肢被 48 小時規則跳過、ME 下肢的主項是熟悉日、ME 上肢和 DE 下肢照常。每個情境都比對四處：<br>① 「下一次」卡：統計快照＋`NextCard.content`<br>② 建立菜單：`PlanMenu`，照 `PlanSheet` 打開時的做法<br>③ 訓練狀態浮窗：輪替列<br>④ 訓練畫面：照建議「開始訓練」建立的訓練<br>比對的內容：主項是同一個動作；「下一次」卡的名稱（DE 速度加「（速度）」）和「熟悉日」與建立菜單的處方一致；動作數等於依日型的預設；訓練狀態的下次主項就是它；訓練畫面第一張卡的動作、角色和說明列的處方（`Prescription`，含熟悉日）和建立菜單相同；動作數和格子的角色也相同。<br>UI：`PlanRulesUITests` 在示範資料上確認畫面上的文字（第 3 節截圖） | 通過 |
| 改寫或刪除的舊測試在報告裡列出 | 見第 3 節 | — |

### 程式碼檢查
| 項目 | 結果 | 驗證方式 |
|---|---|---|
| S1 主項建議、48 小時判斷、熟悉日判斷各只有一個共用函式 | **通過** | 用 grep 查：<br>- **主項建議**：`Rotation.suggestion(now:)`，只有 `PlanRanking.candidates` 的主項格呼叫它。`PlanRanking.suggestedMain` 和 `PlanRanking.resolve` 都經過 `candidates`。「下一次」卡（`StatsSnapshot.suggestedMain`）、訓練狀態（`TrainingStatus.make`）、`-dumpStats` 都呼叫 `suggestedMain`；建立菜單和換動作用 `resolve`／`candidates`。<br>- **48 小時判斷**：`Recovery.isRecent` 一個。`Recovery.deferringRecent` 和 `Rotation.suggestion` 都呼叫它，沒有其他地方算 48 小時。<br>- **熟悉日判斷**：`Prescription.isFamiliarization` 一個，只有 `SlotAdvice.make` 呼叫。「下一次」卡（`NextCard.mainLine`）、建立菜單的處方一行、訓練畫面的說明列（`SessionExercise.advice`）都經過 `SlotAdvice.make`。 |
| S2 「最近一次完成組的時間」和其他地方的「最久沒做」共用同一個資料來源 | **通過** | 定義只有 `SetLogic.lastCompletedDate`：已完成的組的完成時間，沒有時用那次訓練的時間。<br>- 每個動作的值收集在 `PlanHistory.lastCompletedDates`，由 `PlanHistory.withLastDates` 填進候選的 `PlanExercise.lastDate`。「下一次」卡（統計快照）、建立菜單、換動作三處都用它。<br>- 48 小時規則（`Recovery.isRecent`）、「最久沒做」的排序（`sortedByStaleness`）、候選的「N 天前」都讀 `lastDate`。<br>- 統計快照的 `ExerciseStat.lastDate`（動作庫的「N 天前」和排序）也從 `lastCompletedDates` 來；`Exercise.lastCompletedDate`（動作詳情、新增動作）呼叫同一個 `SetLogic.lastCompletedDate`。<br>- grep 確認 `lastDate` 只在這兩個地方寫入：`withLastDates`、`StatsSnapshot.make`。`PlanExercise(_:)` 不再自己算日期。 |
| DEBUG 參數都在 `#if DEBUG` 裡 | **通過** | 腳本列出 38 個 `UserDefaults.standard.<bool｜string｜integer｜double｜object>(forKey: "字面值")`，都在 `#if DEBUG` 區塊內。這次沒有新增參數。 |

### 畫面驗證（`tools/screens/change18/`）
| 項目 | 結果 | 截圖與說明 |
|---|---|---|
| V1 建立菜單，主項被 48 小時規則跳過時的建議原因 | **通過** | `V1_plan_skip_48h.png`：DE 上肢的主項是借力推舉，「建議」膠囊後面寫「臥推（速度）昨天練過，換下一個」（UI 測試用日型的 Menu 換成 DE 上肢後截取，同時確認文字）。 |
| V2 建立菜單和「下一次」卡，ME 主項是熟悉日 | **通過** | `V2_today_familiarization.png`：「下一次」卡「ME 下肢」「主項：前蹲舉・熟悉日」「2 個動作」。`V2_plan_familiarization.png`：ME 主項前蹲舉，處方一行「熟悉日：逐步加到順手的 5 下，不衝極限」和「設好安全槓」；動作數 2 個，沒有第三格。 |
| V3 DE 日預設 3 個動作，第三格是核心 | **通過** | `V1_plan_skip_48h.png`（同一張）：換成 DE 上肢時動作數自動變成 3 個，第三格「核心」。`V3_plan_de_lower_core.png`：DE 下肢也是 3 個、第三格核心。`V3_plan_me_upper_accessory.png`：ME 上肢預設 2 個，改成 3 個時第三格是補強（對照）。 |
| V4 訓練畫面熟悉日的說明列 | **通過** | `V4_workout_familiarization.png`：照建議開始 ME 下肢，前蹲舉（ME 主項）的說明列「熟悉日：逐步加到順手的 5 下，不衝極限・充分休息」和「設好安全槓」，組的「上一次」都是「—」；下一張卡（單腳 RDL）照常。 |
| （每輪重跑）歷程穩定性 | **通過** | 紀錄、統計、動作庫第 1 層、分類清單（核心）各 0.5 秒連拍 5 張，遮掉最上面 200 px 比對都「全部相同」（`stability_pixel_compare.txt`）。 |
| 空資料 | 通過 | `E_today.png`：「ME 下肢」「主項：—」「2 個動作」（ME 日的預設）。`E_plan.png`：動作數 2 個，兩格都是「沒有符合的動作，這一格會略過」，「開始訓練」不能按。 |

另外 `S_training_status.png`：訓練狀態浮窗的輪替四列。DE 上肢「上次 爆發划船 → 下次 借力推舉」（被 48 小時規則跳過，和建立菜單一樣）；ME 下肢「下次 前蹲舉」。

逐張看過：沒有不該有的截斷或重疊。顏色都是主題 token：建議的原因和「建議」膠囊是強調色，「熟悉日」是主要文字色，安全提示是 warning 加圖示。首頁一個畫面放得下（`TodayLayoutUITests` 兩種狀態都通過）。截圖都是乾淨安裝＋示範資料，沒有真實資料。

### 真實資料（R1）
做法照 CHANGE_11 §9：
- 乾淨安裝後用 `-importBackup tools/fixtures/real_backup.json -fakeNow <時間點 1> -dumpStats tools/fixtures/app_1.json` 啟動一次，再用時間點 2 啟動一次（不重新匯入）。
- 兩個時間點由腳本從備份算出（備份最後一筆訓練的隔天中午、之後第一個週一 00:05），只寫在 `tools/fixtures/times.json`。
- `tools/verify_real_data.py` 直接讀備份 JSON、照 SPEC 的規則自己算一次，逐項比對。這次更新的項目：
  - 四個日型的下次主項改成依第 2 節計算：腳本自己從備份每一組的 `completedAt` 算每個動作最近一次完成組，套用 48 小時規則。
  - 新增：每個日型的下次主項是不是熟悉日（ME 的下次主項在已結束的訓練裡沒有任何完成組）、各日型的預設動作數、「下一次」卡的動作數。App 那邊由 `-dumpStats` 用同一套函式輸出。
  - 其他項目照 CHANGE_15。

| 項目 | 時間點 1 | 時間點 2 |
|---|---|---|
| 本週天數、組數（下肢、上肢、其他）、有氧分鐘 | 一致 | 一致 |
| 上週同期 | 一致 | 一致 |
| 本週卡的天數、組數 | 一致 | 一致 |
| 日曆的週數、日曆顯示的每一天的部位 | 一致 | 一致 |
| 本週卡的輪替膠囊 | 一致 | 一致 |
| 本週卡的提醒（分類和天數） | 一致 | 一致 |
| 平衡卡 9 個分類的組數（近 30 天） | 一致 | 一致 |
| 推拉比、單邊次數、爆發次數 | 一致 | 一致 |
| **日型（上次日期、幾天前、上次主項、下次主項）**（下次主項改成 48 小時規則） | 一致 | 一致 |
| 「下一次」的日型 | 一致 | 一致 |
| **各日型的下次主項是不是熟悉日**（新增） | 一致 | 一致 |
| **各日型的預設動作數**（新增） | 一致 | 一致 |
| **「下一次」卡的動作數**（新增） | 一致 | 一致 |
| 主動作的估算 1RM 與 60% 建議重量 | 一致 | 一致 |
| 歷史上每一次訓練的新紀錄（動作） | 一致 | 一致 |

補充：
- 這份備份在這兩個時間點都沒有被跳過的主項，也沒有熟悉日。腳本另外確認，備份最後一組之後 48 小時內的任何時間都不會跳過。所以上表在真實資料上只驗證了「沒有觸發時結果不變」。
- 為了也驗證觸發時的情況，另外做了一份副本 `tools/fixtures/real_backup_48h.json`：在時間點 1 的 20 小時前加一次自由選動作的訓練（沒有日型），內容是四個日型的下次主項各一組。腳本先確認這份副本在時間點 1 有日型的主項被跳過，再照同樣的做法匯入、比對：**全部一致**（包括日型的下次主項、熟悉日、動作數）。
- 比對完把 App 從模擬器移除，之後的測試和截圖都是乾淨安裝＋示範資料。真實資料、副本和所有輸出都只在 `tools/fixtures/`（在 .gitignore 裡，沒有 commit）。

---

## 2. 規格要求查的原因
規格第 1 節的現象已經說明原因：輪替表只看「同日型上次的主項」，不看這個動作最近什麼時候做過，所以別的訓練（另一個日型、或自由選動作）剛做過的動作，輪到時照樣被建議。這次沒有另外要求查原因，照規格加上 48 小時規則。

實作時發現並一起處理的兩件事（都屬於第 5 節「同一套函式」）：
1. 「最近一次完成組的時間」以前有兩份。
   - 「下一次」卡（統計快照）用那次訓練的開始時間，只看已結束的訓練。
   - 建立菜單和換動作用 `Exercise.lastCompletedDate`，用組的完成時間，也算進行中的訓練。
   - 現在統一成 `PlanHistory.lastCompletedDates`（第 1 節 S2）。
2. 「現在」以前也有兩份。
   - 「下一次」卡是存檔或換日時算好的快照，建立菜單是打開時的系統時間。
   - 48 小時是實際時間，不是日曆日，所以快照可能在兩次重算之間跨過某個動作滿 48 小時的時間。那時「下一次」卡還是舊的主項，建立菜單已經換了。
   - 現在快照記下最早的到期時間（`StatsSnapshot.recoveryBoundary`），到了就重算：App 開著時排一次，回到前景時 `StatsRefresh` 也檢查。建立菜單和換動作也改用 `AppClock.now`。

---

## 3. 改寫或刪除的舊測試
刪掉的測試：沒有。舊的「動作數沿用上次」測試改名、改寫，見下表第 4 列。

| 測試 | 改了什麼 | 原因 |
|---|---|---|
| `PlanTests.scenario1NoHistory` | 沒有紀錄時的預設動作數 `countWithoutHistory`（3）→ 2 | §4：ME 下肢預設 2 個；`countWithoutHistory` 刪掉 |
| `PlanTests.scenario7PowerRowAsMainTurnsPullIntoPush` | DE 上肢 3 個＋跑步機的格子：補強 → 核心 | §4 |
| `PlanTests.slotsByDayTypeAndCount` | DE 上肢 3 個的第三格改成核心；加上 DE 下肢 3、ME 上肢 3、主項是拉的 DE 上肢 3 | §4 |
| `PlanTests.countAndCardioDefaultsFromLastSession` → `countDefaultsByDayTypeAndCardioFromLastSession` | 改寫：舊的「動作數同上次重訓、不計有氧」的檢查拿掉，換成依日型；跑步機的檢查保留 | §4：不再沿用上一次 |
| `PlanMenuTests.swappingTheMainRebuildsThePullOrPushSlot` | 換的第三格從補強改成核心（「核心保留」） | §4 |
| `PlanMenuTests` 的 fixture | 候選的最近一次完成組改用 `PlanHistory.withLastDates` 填（和建立菜單的畫面一樣） | §2：`PlanExercise(_:)` 不再自己算日期 |
| `TodayCardsTests.nextCardWithoutAWorkoutShowsThePlanDefaults` | 「1 個動作・跑步機 30 分鐘」→「3 個動作・跑步機 30 分鐘」 | §4：DE 上肢預設 3 個 |
| `TodayCardsTests.mainLineForMaxEffortDynamicEffortAndNoCandidate` | ME「做到 3RM」「做到 5RM」改用有完成組的紀錄；加上沒有紀錄時「主項：槓鈴早安式・熟悉日」 | §3：沒有完成組時是熟悉日 |
| `WidgetSnapshotTests.neverTrained`、`lastSessionAndTodaysSuggestion` | 建議動作數 3 → 2、2 → 3 | §4：小工具的建議和建立菜單同一個預設 |

---

## 4. 自行決定的事項
**§2 48 小時規則**
1. 剛好 48 小時不算「48 小時內」（規格：小於 48 小時）。完成組的時間在現在之後時（只會在 `-fakeNow` 或改系統時間時發生）也算 48 小時內，App 和腳本同一個算法。
2. 只看已結束的訓練，和全 App 的統計一樣。有進行中的訓練時按「建立新菜單」，進行中那次的完成組不算。
3. 其他格子的「排除」做成**排到最後、不從候選刪掉**：
   - 建議（第一個）不會是 48 小時內練過的，除非全部都是；其他照原本的排序。
   - 排到最後的還能在 Menu（前 5 個放得下時）和訓練中的「換動作」清單裡手動選。
   - 全部都在 48 小時內時就是原本的排序，和規格「不排除」相同。
4. 主項被跳過的動作在候選清單裡排到最後；其他的照輪替順序。
5. 全部都在 48 小時內時的原因：「都在 48 小時內練過，選最久沒練的」（規格沒寫原因）。
6. 跳過兩個以上時，原因列出每一個：「臥推昨天練過、肩推今天練過，換下一個」。
7. 時間的寫法：
   - 日曆上是今天、昨天，寫「今天」「昨天」。
   - 前天以前（但還在 48 小時內）寫「47 小時前」，小時無條件捨去。
   - DE 速度主項的名稱加「（速度）」：「臥推（速度）昨天練過，換下一個」。和「下一次」卡的寫法同一個函式 `Rotation.displayName`。
8. 照字面往下找：輪替表裡其他的都在 48 小時內、只有上次用的那個不在時，會建議和上次相同的主項。輪替順序裡上次用的排在最後，所以它是最後才考慮的。
9. 「最近一次完成組的時間」用組的完成時間（以前「下一次」卡和動作庫用那次訓練的開始時間）。沒有完成時間的已完成組用那次訓練的開始時間（真實資料每一組都有完成時間）。動作庫的「N 天前」只有跨過午夜的訓練會差一天。
10. 「下一次」卡在滿 48 小時的時間重算（第 2 節）。只在快照裡記最早的一個到期時間，重算後再找下一個。
11. 建立菜單、換動作的「現在」改用 `AppClock.now`，和統計快照一致（`-fakeNow` 時三處一樣）。
12. 訓練中的「換動作」也套用 48 小時規則。規格說換動作的候選規則和建立菜單同一格相同，而且這次訓練已有的動作照舊排除。
13. 補登也用現在的時間算 48 小時，不是補登那次的時間（輪替、最久沒做本來就用現在）。
14. 有氧格也套用（規格列了有氧）；目前有氧只有跑步機，沒有影響。

**§3 熟悉日**

15. 熟悉日只換處方的文字。組數（5 組）、休息（充分休息、180 秒）、「設好安全槓」照 ME 主項。
16. 「新動作」看這次之前的紀錄：
    - 建立菜單和「下一次」卡：已結束的訓練。
    - 訓練畫面：這次訓練開始之前。所以訓練中打勾後說明列還是熟悉日，完成後的下一輪才恢復。
    - 編輯過去的訓練：看那次之前的紀錄。
17. 「下一次」卡的「熟悉日」和「做到 3RM」一樣是主要文字色，不是建議值的強調色。
18. 訓練狀態浮窗的下次主項照舊只寫名稱，不另外標熟悉日：浮窗本來就沒有處方，四處一致的測試比對名稱。
19. 熟悉日的處方一行沒有「上次 X kg」，因為新動作沒有上次。

**§4 動作數與第三格**

20. 建立菜單裡換日型時，動作數換成那個日型的預設（例如 ME 下肢的 2 換成 DE 上肢的 3）。在這個畫面裡手動改過動作數，就保留使用者選的。
21. `PlanHistory.Session.isStrength`（只給「沿用上次重訓的動作數」用）沒有其他地方用，刪掉。
22. 小工具快照的建議動作數用同一個 `PlanDefaults.answers`，一起改成依日型。

**§5 與驗證**

23. 示範資料（`-demoData`）改了時間線，用來截 V1～V4：
    - 昨天早上 ME 上肢（臥推）。
    - 昨天晚上 DE 上肢（爆發划船，推是啞鈴臥推、第三格核心）。
    - 結果：「下一次」是 ME 下肢、主項前蹲舉是熟悉日；換成 DE 上肢時臥推（速度）被跳過。其他 UI 測試照樣通過。
24. R1 另外做了「加一次自由訓練」的備份副本，讓真實資料也跑到 48 小時跳過的分支（第 1 節）。副本只在 `tools/fixtures/`。

---

## 5. 未解決的事項
- 沒有。**沒有觸發規則 3**：每一節都是一次寫好，全部測試通過後 commit。§4 的新測試第一次寫錯了日型的順序（DE 下肢的下一個是 DE 上肢），改測試後通過，程式沒有改。
- CHANGE_11 留下的兩個 DEBUG 小問題照舊：
  - `-emptyData` 之後再用 `-demoData`，動作沒有輪替順序。
  - `-scrollToBottom 分類` 的最後一列在分頁列後面。
  - 只影響開發用的參數。

---

## 6. 實機確認清單
1. **真實資料的下次主項（規格指定）**：打開「本週」卡 → 訓練狀態，看四個日型的「下次主項」合不合理；「下一次」卡的主項和動作數。如果某個 ME 主項還沒練過，是不是寫「熟悉日」。
2. **48 小時規則**：做完一次訓練後的隔天，打開建立菜單：
   - 主項有沒有避開 48 小時內做過的動作，原因「臥推（速度）昨天練過，換下一個」讀起來順不順。
   - 其他格子的建議有沒有避開；被排到最後的動作還能不能在 Menu 裡選。
3. **滿 48 小時之後**：「下一次」卡的主項會換成輪替表原本的那一個。App 開著時會換，回到前景時也會換。
4. **熟悉日**：建立菜單的處方一行、訓練畫面的說明列；完成那次訓練後，下一輪恢復「逐步加重到當天 3RM」。
5. **動作數**：ME 日預設 2 個、DE 日預設 3 個（第三格核心）。換日型時動作數跟著換，手動改過就保留。

---

## 7. 截圖索引（`tools/screens/change18/`）
| 檔名 | 內容 | 標準 |
|---|---|---|
| `V1_plan_skip_48h.png` | 建立菜單 DE 上肢：借力推舉、「臥推（速度）昨天練過，換下一個」、3 個動作、第三格核心 | V1、V3 |
| `V2_today_familiarization.png` | 今天：「下一次」ME 下肢、「主項：前蹲舉・熟悉日」、「2 個動作」 | V2 |
| `V2_plan_familiarization.png` | 建立菜單 ME 下肢：前蹲舉的處方「熟悉日：逐步加到順手的 5 下，不衝極限」、2 個動作 | V2 |
| `V3_plan_de_lower_core.png` | 建立菜單 DE 下肢：3 個動作、第三格核心 | V3 |
| `V3_plan_me_upper_accessory.png` | 建立菜單 ME 上肢：改成 3 個時第三格補強（對照） | V3 |
| `V4_workout_familiarization.png` | 訓練畫面：前蹲舉的說明列「熟悉日：…・充分休息」和安全提示 | V4 |
| `S_training_status.png` | 訓練狀態：DE 上肢下次借力推舉（被跳過）、ME 下肢下次前蹲舉 | §5 |
| `stability_<records｜stats｜library｜category>_1～5.png` | 捲到底部後每 0.5 秒連拍 | 歷程穩定性 |
| `stability_pixel_compare.txt` | 四組都「全部相同」 | 歷程穩定性 |
| `E_today.png`、`E_plan.png` | 空資料的今天和建立菜單（2 個動作、兩格都略過） | 空狀態 |

V1～V4 是 UI 測試（`PlanRulesUITests`，最後一次全部測試）的附件。其他是 `simctl io screenshot` 配合 DEBUG 參數。全部是乾淨安裝＋示範資料，空資料在最後。

---

## 8. commit 列表
```
c80952c CHANGE_18 §0: save the prompt
c436eda CHANGE_18 §2: the 48-hour rule for the main lift and the other slots
ba24ad6 CHANGE_18 §3: a familiarization day for a new ME main
22bc614 CHANGE_18 §4: exercise count by day type; core is the third slot on DE days
0e8d08d CHANGE_18 §5: the four places agree; demo data and R1 for the new rules
（這份報告、SPEC、STATUS 和截圖的 commit）CHANGE_18: report, SPEC and STATUS updates, verification screenshots
```
