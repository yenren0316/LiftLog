# LiftLog 現況報告（STATUS）

- 產生時間：2026-10-26，對應 commit `a356646`（GitHub `yenren0316/LiftLog` 的 main）。
- 對象：負責 review 和規劃、看不到程式碼的人。內容根據實際程式碼、建置與測試結果整理。
- 平台：iOS 26、SwiftUI＋SwiftData，App 只給自己用，用免費 Apple ID 安裝。
- 規模：App＋共用＋小工具約 8,900 行 Swift，測試約 2,500 行。
- 第 2 節的畫面描述是讀程式碼整理的，標「未驗證」的項目沒有在實機上確認。

---

## 1. 進度總覽

### 1-1. 文件來源
- **repo 裡沒有 CHANGE_01.md～CHANGE_05.md**，整台電腦也找不到。各份 CHANGE 當初是在對話裡提供的，重點已經整併進 `SPEC.md`（開頭有每份 CHANGE 的一行摘要）。
- 因此本節的「每一節」是用 commit 訊息裡的節號（例如 `CHANGE_04 3:`）加上目前的 `SPEC.md` 對照判斷。手上沒有原文的節，無法逐字比對。
- CHANGE_06（共軛訓練 ME/DE）和 10/26 那一輪優化也是在對話裡給的；兩者原文都在同一次對話中，所以判斷比較完整。

### 1-2. 各份 CHANGE 狀態

| 文件 | 節（依 commit） | 狀態 | 說明 |
|---|---|---|---|
| 初版規格 | Phase 1–8 | 完成（多數已被後續取代） | 單筆紀錄頁、今日分頁等在 CHANGE_02 移除 |
| CHANGE_01 | 怪獸訓練分類、UUID、標籤、別名、合併、訓練日曆 | 完成 | 機械類動作當時略過，CHANGE_03 1-2 以「封存」補回 |
| CHANGE_02 | phase 1、2、3、4、5、8 | 完成 | 訓練 → 動作 → 組；訓練中畫面、完成摘要、訓練分頁、休息計時 |
| CHANGE_02 | phase 6、7 | 無法判斷 | 沒有對應 commit。可能併入其他階段，也可能沒做；需要原文確認 |
| CHANGE_03 | 1-1～1-4、2-1、2-2、3、4、5、5-1、5-2 | 完成 | 改名與別名、封存機械、bodyweight／timed、全域 kg/lbs、動作庫排序、動作詳情三分頁、動作說明 |
| CHANGE_04 | 1 動作庫 9 類、2 角色系統 | 完成，之後被 CHANGE_06 改寫 | 舊角色（主項／爆發／單邊）只留在舊紀錄 |
| CHANGE_04 | 3 建立菜單、4 首頁下一次建議 | 完成，之後被 CHANGE_06 取代 | 部位與組合模式已移除 |
| CHANGE_04 | 5 訓練中角色、新增／換動作 | 完成 | 規則已改成 CHANGE_06 的格子 |
| CHANGE_04 | 6 主題（5 個）、7 App icon | 完成，之後被 10/26 優化取代 | 現在是 6 個石墨強調色；icon 改成壺鈴 |
| CHANGE_05 | 0、2、3、4、5、6、7 | 完成 | 小工具、深層連結、鎖定畫面小工具、即時動態、控制項與 App Shortcut |
| CHANGE_05 | 1 | 無法判斷 | 沒有對應 commit（可能是沒有程式的總覽節） |
| 10/26 優化 | 主題、icon、簽署到期日、右下角＋與滑動隱藏分頁列 | 完成 | 分頁列隱藏的 bug 已修，但還沒在實機確認手感 |
| CHANGE_06 | §1 分類與標籤、§2 動作庫 v2、§3 輪替表、§4 建立菜單、§5 參數與建議重量、§6 資料欄位、§7 首頁 | 完成 | 8 個驗收情境都寫成自動測試並通過；差異見 1-3 |

### 1-3. 實作和文件不一樣的地方
- **CHANGE_06 §2 動作數**：文件寫 51 個，清單加總是 52（含跑步機）。實作 52 個。
- **CHANGE_06 §2 輔助引體向上**：
  - 新紀錄記負重的做法：把它的紀錄類型從「輔助重量」改成「重量」，鍵盤列加一個 ± 切換正負。
  - 舊紀錄照指示不轉換，所以舊的「輔助 19 kg」現在顯示成 +19 kg（圖表、上一次、建議重量都受影響）。是否轉換舊紀錄待使用者決定。
- **CHANGE_06 §4 核心格**：文件一處說「爆」動作排除在所有輔助格之外，核心表格又寫「全部 10 個」。實作照表格，所以「單手壺鈴擺盪（爆）」會出現在核心候選。
- **CHANGE_06 §4 日型預設**：文件只說沒有日型的「舊紀錄」不算。實作跳過所有沒有日型的訓練，包括之後的空白訓練，只看最近一次有日型的訓練。
- **CHANGE_06 §5 參數**：文件只給範圍，實作必須選定值，選的是：
  - 新增時組數：ME 5、DE 速度 8／6／8、DE 爆 6、輔助 3、核心與補強 3、有氧 1。
  - 休息計時：ME 180 秒、DE 速度 60、DE 爆 90、輔助 90、核心與補強 60。
  - 建議重量在 lbs 模式取整到 5 lb。
- **CHANGE_06 §7 首頁**：
  - 「最近 30 天」組數的顏色門檻是自訂的：0 組紅、未滿 10 組黃、10 組以上綠。
  - 「單邊／爆發」次數改成依動作標籤計算，因為新菜單不再指定這兩種角色。
  - 「主」動作還沒有 ME 紀錄時，清單照舊顯示上次紀錄。
- **沒經過建立菜單加入的動作**（空白訓練、訓練中新增）依分類給角色，下肢動作一律是「下肢輔助」。ME／DE 主項只由建立菜單指定，避免手動加的深蹲變成 ME 紀錄。
- **文件以外加做的**：小工具和訓練列表改顯示日型；備份格式升到 v5。
- **SPEC.md 已過期的段落**：
  - 「初始資料」還寫 `LibraryAdditions.names`（只有啞鈴上斜臥推、旗標 v1）。實際已經有第二批（v2，9 個動作）。
  - `tools/theme_previews/` 的截圖還是舊的 5 個主題。

### 1-4. git log 摘要（共 52 筆，新 → 舊）
```
a356646 CHANGE_06: conjugate (ME/DE) library and plan builder
c3c6fee Fix the tab bar hiding only at the bottom, or never on lists
094a898 Hide the tab bar on scroll; floating plus on the home screen
7aad55a Show the signing expiry date at the bottom of Settings
6cd841d App icon: kettlebell with a rising line, midnight blue
1466b4f Graphite themes with six accent colors
fe659bb Smoother tap feedback and state transitions
3f2a313 Fix crash when SwiftUI renders off the main thread on device
7695f6f CHANGE_05: widget, Live Activity and control previews for review
d2cabba CHANGE_05 7: 開始訓練 control and App Shortcut
5e4aff7 CHANGE_05 6: workout Live Activity with set and rest buttons
2e841ad CHANGE_05 5: lock screen widgets
dfe1fd0 CHANGE_05 4: small "上次訓練" widget
0b06d11 CHANGE_05 3: liftlog:// deep links
b0980ba CHANGE_05 2: widget snapshot in the App Group
2a8c796 Keep the SwiftData store out of the App Group container
5feff44 CHANGE_05 0: widget extension target, Live Activities, URL scheme, App Groups
56c3af3 CHANGE_04 7: app icon (diagonal dumbbell, midnight blue)
06d70c1 Twelve dumbbell icon variants for review
939a756 Ten kettlebell icon variants for review
1a1adf1 Add 啞鈴上斜臥推 to the library
64565fe CHANGE_04 7: three app icon concepts for review
6c38751 CHANGE_04 6: theme tokens, five themes and theme settings
13d1368 CHANGE_04 5: roles in the workout screen, role-based sets and rest, new add and replace sheets
28d0733 CHANGE_04 4: home next-plan card and role counts
45ca468 CHANGE_04 3: guided plan builder from the home plus button
dab176e CHANGE_04 2: role system, session region and mode, backup v4
792685c CHANGE_04 1: reorganize exercise library into nine categories
e755c14 Update SPEC.md for CHANGE_03
df2053d CHANGE_03 5-2: exercise guides
9a1b5bf CHANGE_03 5, 5-1: exercise detail with data/guide/history tabs
32d9c99 CHANGE_03 4: untrained exercises collapse on home and sort last in pickers
7381bd4 CHANGE_03 3: library ordering, collapsible sections, two-group filter
e9ab098 CHANGE_03 2-1/2-2: global kg/lbs setting and per-dumbbell weights
c7d08d8 CHANGE_03 1-3/1-4: bodyweight and timed log types, 16 new exercises
0afa1b6 CHANGE_03 1-1/1-2: rename, aliases, archived machines with history
fabd21b CHANGE_02 phase 8: rest timer, plus SPEC.md update
86a0faa CHANGE_02 phase 5: workouts tab and editable history
16cdfc6 CHANGE_02 phase 4: finish flow and workout summary
83e1bed CHANGE_02 phase 3: start-workout entry points
f0a1bbf CHANGE_02 phase 2: live workout screen
0a08f2f CHANGE_02 phase 1: session/exercise/set model and migration from v2
7df6c7d Import treadmill sessions from Apple Watch via HealthKit
e196bd0 Spec v2: Monster Training categories, tags, aliases, merge, activity graph
（更早 8 筆：初版 Phase 1–8，資料模型、解析舊紀錄、首頁、記錄頁、今日、動作詳情、動作庫、設定與備份）
```

---

## 2. 畫面清單

> 共通：顏色都走主題 token（`Theme.*`），App 固定深色；字級都用系統語意字型。以下只列例外。
> 卡片圓角 token 是 28，但有幾處自己寫死 8／12／16／20。

**2-1. 分頁殼與訓練中橫條**
- 用途：4 個分頁（該練什麼／訓練／動作庫／設定）；有進行中訓練時，每個分頁底部都有「訓練中」橫條。
- 檔案：`Views/RootView.swift`（154）、`Views/Workout/WorkoutCoordinator.swift`（120，橫條在 63–98 行）。
- 進入：App 啟動。
- 版面：TabView。橫條是膠囊形：圖示、訓練名稱、每秒更新的「訓練中 m:ss」、⌃。
- 互動：
  - 點分頁切換；點橫條展開訓練中全螢幕。
  - 分頁內往下滑超過 24 pt 隱藏分頁列，往上滑或回到頂端恢復。
  - 深層連結 `liftlog://new`、`liftlog://workout` 在這裡導向。
- 狀態：
  - 完成時一組都沒打勾：alert「沒有完成任何一組」。
  - 已有訓練又要開新的：對話框「加入目前的訓練／結束並開始新的／取消」。
- 寫死：橫條高 56；換主題時整棵 TabView 用 `.id(theme)` 重建（0.35 秒）；導向等 600 ms 才開 sheet；分頁用 Int 0–3，沒有 enum。

**2-2. 首頁「該練什麼」**
- 用途：一眼看到下一次練什麼、主項 ME 紀錄、近 30 天組數、依多久沒練排序的全部動作。
- 檔案：`Views/Home/HomeView.swift`（488，8 個型別）、`ActivityGraph.swift`（94）。
- 進入：tab 0（預設）。
- 版面：
  - 標題「該練什麼」；「下一次」卡（日型大字、「建議主項：X」、「N 個動作・加／不加跑步機」）；訓練日曆（53 週格子，可橫向捲動）。
  - 「主項紀錄」：12 個「主」動作，各列重量 × 次數・日期、估 1RM、「比上次 ±X」。
  - 「最近 30 天」：各分類組數長條、推：拉組數比（拉少於推時黃色）、單邊／爆發次數、有氧天數。
  - 篩選「全部／主項／單邊／爆發」；分類卡（動作名、上次日期與精簡紀錄、幾天前；未練過的收在「還沒練過（N）」）；圖例。
- 互動：
  - 點「下一次」卡：帶預設答案開建立菜單；點主項列或動作列：push 動作詳情；點長條：捲到該分類。
  - 往下滑：分頁列隱藏，右下浮出圓形＋（開建立菜單）。
- 狀態：訓練中按＋或「下一次」會先問「繼續目前訓練／結束並建立新菜單」；主項沒有 ME 紀錄時「尚無紀錄」；篩選沒有結果時「沒有符合的動作」；完全沒紀錄時「ME 下肢・3 個動作」。
- 寫死：日格 13 pt、間距 4；60／180 天門檻直接寫在圖例字串；次數顏色 0／1–2／3+；＋按鈕 60×60、陰影 `.black.opacity(0.4)`。

**2-3. 建立菜單 第 1 步（三個問題）**
- 用途：選日型、動作數、要不要加跑步機，都已預先選好。
- 檔案：`Views/Plan/PlanFlowView.swift`（397，11 個型別），邏輯在 `Logic/PlanBuilder.swift`（432）。
- 進入：首頁「下一次」卡或＋（sheet）；`liftlog://new`（小工具、控制項、Siri）。
- 版面：
  - 「今天的日型」2×2 膠囊：ME 下肢／ME 上肢／DE 下肢／DE 上肢。
  - 「今天做幾個動作？」1／2／3。
  - 「最後要加跑步機嗎？」加／不加。
  - 「今天的順序」：格子膠囊用 → 串起來，放不下會換行。
  - 底部「下一步」。
- 互動：點選項即時更新順序預覽；「下一步」清掉之前的選擇並進入第 2 步；「取消」或下拉關閉。
- 狀態：快照建立前顯示 ProgressView。
- 寫死：膠囊高 52、主按鈕高 60。順序預覽依預設會選到的主項決定（已修正和第二步不一致的問題）。

**2-4. 建立菜單 第 2 步（選動作）**
- 用途：每一格選一個動作，然後開始訓練。
- 檔案：同上（ExercisesStep、SlotCard、CandidateRow）。
- 進入：第 1 步「下一步」（push）。
- 版面：每一格一張卡，底部是「開始訓練」。卡片內容依序是：
  - 角色標題＋ⓘ；參數「8 組 × 2 下・休息 45–60 秒」；建議重量（「建議 65 kg（估算 1RM 110 kg × 60%）」／「上次 60 kg」／「用能做得很快的重量」）；⚠ 提示。
  - 最多 5 個候選：單選圈、名稱、標籤、「新」；第一個標「建議」＋原因；右側「N 天」。
- 互動：
  - 點候選：選定。主項改變時其他格重排，「拉」和「推」可能互換。ⓘ：popover 顯示角色完整說明。
  - 「開始訓練」：建立訓練（寫入日型和每格的角色），關 sheet 後展開訓練中畫面。
- 狀態：某格沒有候選時「這一格會略過」；有氧格固定跑步機；一格都沒選時按鈕停用。
- 寫死：候選上限 5；有氧用名稱字串「跑步機」判斷；DE 速度重量 = 1RM × 60%，取整到 2.5 kg／5 lb。

**2-5. 訓練中畫面**
- 用途：逐組記錄、打勾、休息倒數。歷史詳情也共用同一個編輯器。
- 檔案：`Views/Workout/WorkoutView.swift`（113）、`WorkoutEditor.swift`（425）、`SetRow.swift`（164）、`RestTimerBar.swift`（62）。
- 進入：RootView 的 fullScreenCover。來源有建立菜單、開始空白訓練、動作詳情、再做一次、點訓練中橫條、`liftlog://workout`。
- 版面：
  - 導覽列（縮小、計時器選單、⋯ 捨棄、完成）；休息倒數條（-15／+15／跳過／進度條）；標題欄位、開始時間、經過時間。
  - 每個動作一張卡：名稱＋角色徽章＋標籤；參數行；欄位標題；各組列（組號｜上一次｜輸入格｜✓）；「新增一組」。最下面「新增動作」。
- 互動：
  - ✓：空格用灰字預填補齊再完成，並開始休息；欄位不足時整列晃動。點組號：正式／熱身／MAX／刪除；組列可左滑刪除。
  - 卡片 ⋯：換動作、加備註、上移、下移、移除（有氧另有「從 Apple Watch 帶入」）。鍵盤列：±（只有可以記負重的動作）、-2.5、+2.5、+5、下一格、完成。
- 狀態：完成的列鋪 done 色 18%；沒有上一次紀錄顯示「—」；DE 速度主項沒有上次 DE 紀錄時，灰字預填建議重量。
- 寫死：欄寬 34／64／40；鍵盤步進不分器材；計時器預設秒數取「最後一張卡」。

**2-6. 完成訓練（確認與摘要）**
- 用途：處理沒打勾的組，顯示這次的成果。
- 檔案：`Views/Workout/WorkoutSummaryView.swift`（118，含 WorkoutSummary 資料）。
- 進入：訓練中「完成」。有沒打勾的組時，先選「刪除未完成的組／全部標為完成／取消」；成功後同一個全螢幕改顯示摘要。從衝突對話框「結束並開始新的」結束的訓練不顯示摘要。
- 版面：「訓練完成」、訓練名稱；統計（總時長｜動作｜組）；「新紀錄」卡（🏆）；各動作卡（組數、精簡紀錄）；「完成」。
- 互動：只有捲動和「完成」（關閉）。
- 狀態：沒有新紀錄時隱藏該卡；第一次做的動作和有氧不算新紀錄。
- 寫死：`.system(size: 48)` 圖示、`.system(size: 28)` 數字，兩者不跟 Dynamic Type。

**2-7. 新增動作（訓練中，sheet）**
- 用途：自由多選加入動作。
- 檔案：`Views/Workout/AddExercisesSheet.swift`（194）。
- 進入：訓練中或歷史詳情最下面的「新增動作」。
- 版面：
  - 搜尋列。
  - 分類 chips 列、標籤 chips 列（全部／主項／單邊／爆發），兩者取交集。
  - 依分類分區、可收合；每列是勾選圈、名稱、標籤，右邊「已加入」／「N 天前」／「新」。
  - 底部：已選膠囊（可移除）＋「加入（N）」。
- 互動：多選並保留點選順序；加入時角色依分類決定，加完捲到最後一張卡。
- 狀態：沒有結果時「沒有符合的動作」；已在訓練中的動作停用；不列封存動作。
- 寫死：按鈕高 56、chip 高 36；天數寫「N 天前」，和建立菜單的「N 天」不一致。

**2-8. 換動作（sheet）**
- 用途：換掉一張卡的動作，候選和排序跟建立菜單同一格一樣。
- 檔案：`Views/Workout/ReplaceExerciseSheet.swift`（68）；列元件借用 PlanFlowView 裡的 CandidateRow。
- 進入：卡片 ⋯ →「換動作」；已有完成組時先跳確認。
- 版面：「格子：{角色}」＋一句說明，下面是全部候選（不限 5 個），第一名標「建議」。
- 互動：點候選就換掉並關閉；角色保留原格子的角色。
- 狀態：
  - 排序算完前只看得到說明（沒有 loading）。
  - CHANGE_04 舊角色的卡片一律當作「下肢輔助」格，所以上肢的舊卡也只會出現下肢候選（見 5-3）。
  - 空白訓練沒有日型時，ME／DE 格改列所有「主」動作。

**2-9. 從 Apple Watch 帶入（sheet）**
- 用途：把「健康」裡最近 7 天的室內步行／跑步，帶入有氧的一組（分鐘、平均速度）。
- 檔案：`Views/Log/HealthImportSheet.swift`（103）、`Logic/HealthWorkouts.swift`（70）。
- 進入：有氧卡 ⋯ →「從 Apple Watch 帶入」（只有 HealthKit 可用時才出現）。
- 版面：每列是類型＋日期時間、「N 分・x km・y km/h」、來源 App。
- 互動：點一筆寫入第一個未打勾的組；跑步會自動備註「跑步」；不會自動打勾，也不填坡度。
- 狀態：載入中 ProgressView；錯誤紅字；空的時候有兩種文案（都帶入過了／沒找到＋開權限路徑）；已帶入的不顯示。
- 寫死：「7 天」在字串寫了 3 次，查詢參數另寫一次。

**2-10. 訓練分頁**
- 用途：進行中訓練的入口，加上歷史列表。
- 檔案：`Views/Sessions/SessionsView.swift`（121）。
- 進入：tab 1。
- 版面：
  - 大標題「訓練」。
  - 「進行中」卡（名稱、經過時間）或「開始空白訓練」大按鈕。
  - 「歷史訓練（N）」：每列是日期＋星期、時長、名稱、「日型・N 個動作」。
- 互動：點進行中卡展開訓練；點一列 push 詳情；左滑「刪除」需確認。
- 狀態：沒有歷史時只剩「歷史訓練（0）」，沒有空狀態文字；匯入的舊訓練不顯示時長。

**2-11. 訓練詳情（歷史）**
- 用途：檢視和修改一次過去的訓練。
- 檔案：`Views/Sessions/SessionDetailView.swift`（68）＋共用 WorkoutEditor。
- 進入：訓練分頁的列、動作詳情的歷史分頁、數據分頁的紀錄或圖表點。
- 版面：標題是日期、右上「再做一次」、分頁列隱藏；標題欄位、DatePicker、時長；下面是和訓練中相同的卡片，但沒有休息條。
- 互動：
  - 改日期時，結束時間和每組的完成時間一起平移。
  - 「再做一次」帶入同樣的動作、順序、角色和日型；舊角色改用分類的角色。
- 狀態：舊匯入的訓練只有日期，沒有時間。

**2-12. 動作庫**
- 用途：瀏覽、搜尋、篩選、封存、合併、刪除動作。
- 檔案：`Views/Library/LibraryView.swift`（196），篩選與排序在 `Logic/ExerciseFilter.swift`（134）。
- 進入：tab 2。
- 版面：
  - 大標題「動作庫」＋「＋」；常駐搜尋列；篩選兩排（「全部／練過／未練過」單選，「主項／單邊／爆發」複選取交集）；「顯示已封存」。
  - 9 個分類段落，可收合；每列是名稱、標籤、「上次 日期」或「未練過」、「N 次」；footer 提示長按。
- 互動：點列 push 詳情；左滑封存或取消封存；長按選單有「合併到…」、封存、刪除（只有沒紀錄的動作才能刪，需確認）。
- 狀態：封存的列半透明；篩選沒有結果時沒有空狀態提示。
- 寫死：chip 高 34（首頁的篩選是 40，樣式不同）。

**2-13. 新增／編輯動作（sheet）**
- 用途：動作的基本設定。新增和編輯共用一個表單。
- 檔案：`Views/Library/ExerciseEditView.swift`（174）。
- 進入：動作庫「＋」（新增）；動作詳情右上「編輯」。
- 版面（Form）：
  - 名稱、英文名。
  - 分類＋主項／單邊／爆發三個開關。
  - 別名清單＋新增。
  - 器材、紀錄方式。
  - 自訂休息時間（Stepper 15–600 秒）。
  - 備註。
  - 封存（只有編輯時有）。
- 互動：名稱空白或重名時「儲存」停用；「取消」不確認就丟棄。
- 寫死：新增時預設分類永遠是「下肢推」；休息時間說明已更新為目前的規則。

**2-14. 合併到…（sheet）**
- 用途：把一個動作的紀錄併入另一個動作，來源的名稱變成目標的別名，然後刪除來源。
- 檔案：`Views/Library/MergeTargetView.swift`（81）、`Logic/ExerciseMerge.swift`（40）。
- 進入：動作庫長按 →「合併到…」。
- 版面：搜尋、說明文字、依分類列出候選（名稱、N 次）。
- 互動：點候選 → 確認「這個動作無法復原」→ 合併並關閉；失敗時跳 alert。
- 狀態：候選包含封存動作，但沒有標示；排序只依名稱。

**2-15. 動作詳情（頁首）**
- 用途：單一動作的總覽，下面切換「數據／說明／歷史」三個分頁。
- 檔案：`Views/Detail/ExerciseDetailView.swift`（175，歷史分頁也在這個檔案）。
- 進入：動作庫列、首頁主項列和動作列、訓練中點動作名、數據分頁的替代動作。
- 版面：
  - 頁首卡：名稱＋標籤、「分類 · 器材」、「上次」、「近 90 天 N 次」、大按鈕。
  - 下面是分段切換。
- 互動：右上「編輯」開 2-13。大按鈕在沒有訓練中時是「用這個動作開始訓練」，有訓練中時是「加入目前訓練」（並展開訓練畫面）。
- 狀態：「上次」依 60／180 天上色；沒練過時顯示紅色「未練過」。

**2-16. 動作詳情：數據**
- 檔案：`Views/Detail/ExerciseDataTab.swift`（365，裡面還放了設定頁用的 RoundingSteps）。
- 版面：
  - 個人紀錄卡。
  - 趨勢圖：kg/lb 切換、指標、範圍 3 個月／6 個月／1 年／全部；MAX 用菱形。
  - 強度換算表：60–95%，只有重量類有。
  - 同分類替代動作，最多 5 個。
- 互動：
  - 點紀錄或圖上的點：開那次訓練。
  - 長按拖曳：看數值。
  - 這裡的 kg/lb 切換會改全 App 的單位（見 5-3）。
- 狀態：「還沒有紀錄」；少於 2 點時「紀錄不足，無法畫圖」；輔助類的 Y 軸反轉，標「越低越好」。
- 寫死：圖高 220；用途顏色門檻 85%／75% 寫在畫面裡。

**2-17. 動作詳情：說明**
- 檔案：`Views/Detail/ExerciseGuideTab.swift`（141，含說明編輯 sheet）。
- 版面：「動作說明」卡（核心抗動類型、要點、常見錯誤、退階、進階，右上「編輯」）、「我的筆記」卡。
- 互動：「編輯」開 TextEditor，一行一條。
- 狀態：空欄位顯示「—」；沒有筆記時有提示文字。內容在第一次啟動時從 `ExerciseGuides.json` 匯入；教練變化動作標「待補（請向教練確認）」。

**2-18. 動作詳情：歷史**
- 檔案：`ExerciseDetailView.swift` 122–175 行（沒有獨立檔案）。
- 版面：「全部紀錄（N 次）」，每次訓練一列：日期、精簡紀錄、備註。
- 互動：點一列 push 訓練詳情。
- 狀態：沒有紀錄時「還沒有紀錄」；有 MAX 組時數字是 warning 色；一次全部列出，不分頁。

**2-19. 設定（含主題）**
- 用途：主題、單位、進位、休息與即時動態開關、備份、版本與簽署到期日。
- 檔案：`Views/Settings/SettingsView.swift`（218）、`ThemeSection.swift`（97）。
- 進入：tab 3。
- 版面：
  - 主題卡：2 欄 6 張預覽卡，每張用該主題自己的色票畫出迷你畫面。
  - 重量單位 kg／lbs；強度換算表進位（4 個 Stepper）；打勾後自動休息計時（開關＋說明）；訓練中顯示即時動態（開關）。
  - 備份卡（三個統計數字、「匯出 JSON」、「從 JSON 匯入」）；最下方 LiftLog、版本、「簽署到期 日期・還有 N 天」。
- 互動：點主題立即換主題，整棵畫面重建；匯入要先確認「取代目前所有資料？」才執行。
- 狀態：模擬器取不到簽署檔，不顯示到期列；剩 1 天以內用黃色；匯出檔產生失敗時會跳 alert。
- 寫死：預覽卡用 `Color(hex:)`（刻意，要畫出其他主題的顏色）；統計數字 `.system(size: 30)`；休息秒數說明已更新；`"autoRestTimer"` 直接寫字串，沒用已有的常數。

**2-20. 小工具「上次訓練」（主畫面小型、鎖定畫面三種）**
- 檔案：`LiftLogWidgets/LastWorkoutWidget.swift`（54）、`Shared/LastWorkoutViews.swift`（214）、`Shared/WidgetSnapshot.swift`（73）、`Logic/SnapshotWriter.swift`（66）。
- 進入：使用者從系統的小工具清單加入。App 在三個時機把快照寫進 App Group，內容有變才請小工具重新載入：啟動、每次存檔、換主題。
- 版面：
  - 小型：「上次訓練」、大字「2 天前」、「ME 下肢・10/23」、「今天建議：ME 上肢」。
  - 圓形：天數＋「天」。
  - 矩形：「上次：…」和「今天：…」兩行。
  - 單行：「上次訓練 2 天前・今天 ME 上肢」。
- 互動：點整個小工具，訓練中開 `liftlog://workout`，否則開 `liftlog://new`。
- 狀態：
  - 從沒訓練：「還沒有紀錄／開始第一次訓練」。
  - 訓練中：即時計時，圓形顯示啞鈴。
  - 今天練過：前綴改成「下次」，圓形顯示勾。
  - timeline 是現在加上之後 7 個午夜，天數不用 App 喚醒也會往上加。
- 寫死：`.system(size: 44/34/26)`；顏色用快照裡主題 id 對應的 `Color(hex:)`。

**2-21. 即時動態／動態島**
- 檔案：
  - `LiftLogWidgets/WorkoutLiveActivity.swift`（43）
  - `Shared/WorkoutActivityViews.swift`（167）、`WorkoutActivityAttributes.swift`（43）、`WorkoutIntents.swift`（31）
  - `Logic/LiveActivityController.swift`（137）
- 進入：有進行中的訓練就自動出現；設定頁可以關掉。
- 版面：
  - 鎖定畫面：標題＋經過時間；目前的組（角色、動作、第 n／m 組、目標「60 kg × 5」）。
  - 休息中：大字倒數、進度條、下一組。
  - 動態島：縮小時「2/5」或倒數；展開時和鎖定畫面相同。
- 互動：「完成這組」（用預填值打勾並開始休息）、「跳過休息」、「+15 秒」；點其他地方打開 App。
- 狀態：沒有預填值時改成「打開 App 輸入這組」；全部完成時「全部的組都完成了」；App 在背景時無法建立，會靜默失敗。
- 寫死：背景 `Color.black.opacity(0.72)`、白字；倒數 `.system(size: 44/32)`；「15 秒」寫在三個地方。

**2-22. 控制中心「開始訓練」與 App Shortcut**
- 檔案：`LiftLogWidgets/StartWorkoutControl.swift`（16）、`Intents/AppShortcuts.swift`（17）。
- 進入：控制中心或動作按鈕加入；Siri 說「用 LiftLog 開始訓練」。
- 版面：系統繪製的單一按鈕「開始訓練」（啞鈴圖示）。
- 互動：打開 App 並走 `liftlog://new` 的導向：有進行中訓練就展開，沒有就開建立菜單。
- 狀態：控制項本身沒有狀態，不會顯示是否在訓練中。

**2-23. 開發用小工具預覽頁（只有 DEBUG）**
- 檔案：`Views/Debug/WidgetGalleryView.swift`（241）。
- 進入：啟動參數 `-widgetGallery small|lock|live|island|control`。
- 用途：模擬器無法加小工具或鎖定畫面，所以用同一份 Shared 畫面排出來截圖。
- 寫死：大量模擬用的顏色和尺寸；裡面的「完成這組」是真的 intent 按鈕（見 5-3）。

---

## 3. 導覽地圖
```
LiftLogApp → RootView（TabView，固定深色）
├─ [tab 0] 該練什麼 HomeView（NavigationStack）
│   ├─ push → 動作詳情 ExerciseDetailView
│   │   ├─ 分段：數據 ─ push → 訓練詳情 SessionDetailView（點紀錄／圖上的點）
│   │   │           └ push → 動作詳情（同分類替代動作）
│   │   ├─ 分段：說明 ─ sheet → 說明編輯 GuideEditView
│   │   ├─ 分段：歷史 ─ push → 訓練詳情
│   │   ├─ sheet → 編輯動作 ExerciseEditView（右上「編輯」）
│   │   └─ 「用這個動作開始訓練／加入目前訓練」→ 訓練中（full screen）
│   ├─ sheet → 建立菜單 PlanFlowView：第 1 步 ─ push → 第 2 步 ─「開始訓練」→ 訓練中
│   │         （訓練中時先跳 confirmationDialog）
│   └─ 浮動＋（往下滑才出現）→ 建立菜單
├─ [tab 1] 訓練 SessionsView（NavigationStack）
│   ├─ 進行中卡 → 訓練中
│   ├─ 開始空白訓練 → 訓練中
│   └─ push → 訓練詳情 ─ 再做一次 → 訓練中（已有訓練時跳衝突對話框）
├─ [tab 2] 動作庫 LibraryView（NavigationStack）
│   ├─ push → 動作詳情（同上）
│   ├─ sheet → 新增動作 ExerciseEditView
│   └─ 長按 → sheet → 合併到… MergeTargetView
├─ [tab 3] 設定 SettingsView ─ ShareLink 匯出／fileImporter 匯入
├─ 各分頁底部：訓練中橫條 → 訓練中
└─ fullScreenCover：訓練中 WorkoutView（或完成後的 WorkoutSummaryView）
    ├─ sheet → 新增動作 AddExercisesSheet
    ├─ sheet → 換動作 ReplaceExerciseSheet
    ├─ sheet → 從 Apple Watch 帶入 HealthImportSheet
    ├─ push → 動作詳情（點動作名稱）
    └─ 完成 → 確認對話框 → 摘要 → 關閉

深層連結 liftlog://（onOpenURL、控制項、App Shortcut 都交給 DeepLinkRouter → RootView）
├─ liftlog://workout：有進行中訓練就展開，沒有就回首頁
└─ liftlog://new：有進行中訓練就展開，沒有就切到首頁並開建立菜單（摘要開著時等 600 ms）
系統畫面：小工具（點 → new／workout）、即時動態（點 → workout；按鈕在 App 程序內直接執行）
```

---

## 4. 架構

### 4-1. 目錄結構（行數）
```
LiftLog/                     App target
  LiftLogApp.swift           進入點，啟動時把舊主題設定轉成新的
  Models/   Models.swift、Enums.swift                     379
  Logic/    22 檔：建立菜單、角色、訓練操作、統計、計時、即時動態等    2,477
  Data/     Backup.swift（備份、seed 匯入、動作庫補充、說明匯入）、seed.json、ExerciseGuides.json  487＋JSON
  Theme/    Components.swift（共用畫面元件、按鈕樣式、分頁列自動隱藏）   220
  Intents/  即時動態按鈕的 perform、App Shortcut                66
  Views/    Home 582、Plan 397、Workout 1,264、Sessions 189、Library 451、
            Detail 681、Settings 315、Log 103、Debug 241
Shared/     App 和小工具共用：主題、日型、部位、快照、深層連結、即時動態畫面、intent 宣告   745
LiftLogWidgets/  小工具 target：小工具、即時動態、控制項                144
LiftLogTests/    25 檔，Swift Testing                              2,459
tools/      parse_log.py（舊紀錄 → seed.json）、icon 產生器、預覽截圖
```

### 4-2. 資料模型（SwiftData，存在 App 自己容器裡的 `LiftLog4.store`）
- **Exercise**：
  - id（UUID，不變）、name、category（9 類）、tags（主／單／爆，可多選）、aliases、englishName、equipment、logType（weight／assisted／bodyweight／timed／cardio）、note、isArchived。
  - restSeconds（自訂休息）、meRotation／deRotation（主項輪替順序）。
  - 說明欄位 guideCore／Cues／Mistakes／Regression／Progression、myNotes。
  - → sessionItems（cascade）。
- **WorkoutSession**：
  - id、startedAt、endedAt（進行中為 nil）、title、note、hasTime（舊匯入為 false）。
  - dayType（ME/DE × 下肢/上肢，可空）。
  - region（完成時推算）、modeID（CHANGE_04 遺留）。
  - → items（cascade）。同一時間最多一個進行中。
- **SessionExercise**：id、session、exercise、order、note、role（新角色 8 種＋舊角色 3 種）→ sets（cascade）。
- **SetRecord**：id、order、kind（正式／熱身／MAX）、weightKg、reps、incline、speed、minutes、seconds、isCompleted、completedAt、healthWorkoutID。
- **BodyWeight**：date、kg（只存資料，還沒有畫面）。
- **其他持久化**：
  - UserDefaults：`theme.id`、`weightUnit`、`autoRestTimer`、`liveActivity.enabled`、`round.*`、`restTimer.endDate`、`restTimer.duration`、`library.*`。
  - 一次性旗標：`libraryAdditions.v1/v2`、`conjugateLibrary.v1`、`guidesImported.v2`。
  - App Group：小工具快照 `widgetSnapshot.v1`。
- **備份 JSON**：version 5；可以讀 v2（seed）、v3、v4。

### 4-3. 服務與狀態
- `LiftLogStore.container`：唯一的 ModelContainer。畫面和即時動態按鈕共用 mainContext。
- `WorkoutCoordinator`（@Observable，environment）：全螢幕或縮小、摘要、開始衝突、深層連結旗標。
- `RestTimer.shared`（@Observable，environment）：休息倒數，結束時間存在 UserDefaults，背景有本機通知。
- `WorkoutService.shared`：完成一組、跳過休息、延長休息。訓練中畫面和即時動態按鈕共用。
- `WorkoutActions`（static）：開始、加入、打勾、換動作、移除、完成、捨棄，每次修改後立即存檔。
- `DeepLinkRouter.shared`：pending 連結，由 RootView 消化。
- `SnapshotWriter.shared`：在存檔、啟動、換主題時寫小工具快照。
- `LiveActivityController.shared`：依進行中訓練建立、更新、結束即時動態（合併成 150 ms 一次）。
- 純邏輯（可單元測試）：PlanBuilder（PlanHistory、PlanRanking、Rotation、MaxEffortRecords、SlotAdvice）、Roles（Prescription）、SetLogic、ExerciseStats、Recency、HomeStats、TabBarAutoHide、ProvisioningProfile。
- 畫面之間的狀態傳遞：
  - 資料靠 `@Query` 直接讀 SwiftData。
  - 設定靠 `@AppStorage`。
  - 跨畫面的訓練狀態靠 environment 裡的 coordinator 和 restTimer。
  - 建立菜單建立訓練後用 callback 通知首頁，sheet 關閉後才展開訓練中畫面。

### 4-4. 共用元件與「該共用卻沒共用」
- 已共用（`Theme/Components.swift`）：CardModifier（`.card()`）、ScreenHeader、ThinBar、Chip、TagFilterBar、FloatingActionButton、PressableButtonStyle（`.pressable`）、`.hidesTabBarOnScroll()`。
- 跨畫面在用、卻放在畫面檔裡：AccentChip、CandidateRow、WrapLayout（PlanFlowView）、FilterChip（AddExercisesSheet）、RoleBadge（WorkoutEditor）、RoundingSteps（ExerciseDataTab，設定頁也在用）。
- 重複刻了多份：
  - accent 大膠囊按鈕：建立菜單、摘要、新增動作、訓練分頁、設定，高度各自寫死 52／54／56／60。
  - 篩選膠囊：首頁 TagFilterBar 高 40；動作庫 chip() 高 34；新增動作 FilterChip 高 36。
  - 每秒更新的經過時間：3 份。
  - 「今天／N 天前」格式化：4 處；天數寫法有三種（「N 天」「N 天前」「天前」）。
  - 「已經有進行中的訓練」對話框：首頁和 coordinator 各一份。

---

## 5. 品質狀況

### 5-1. 建置
- 指令：`xcodebuild … build-for-testing`，用全新的 DerivedData，App、小工具、測試共 130 個 Swift 編譯步驟。
- 結果：**0 個 warning、0 個 error**。

### 5-2. 測試
- **172 個全部通過，0 失敗，0 略過**（27 個測試組）。
- 各組數量：
  - PlanTests 18、WorkoutActionsTests 14、WorkoutServiceTests 14、RecencyTests 12、SetLogicTests 12、ExerciseStatsTests 11
  - WidgetSnapshotTests 9、TabBarAutoHideTests 8、LibraryAdditionsTests 6、LogTypeAndUnitTests 6、MigrationTests 6
  - BackupTests 5、RoleTests 5、ThemeTests 5、DeepLinkTests 4、LibraryLayoutTests 4、LibraryTests 4、PrescriptionTests 4
  - 其餘 9 組各 2–3 個
- 涵蓋：CHANGE_06 的 8 個驗收情境都有對應測試。
- 沒有 UI 測試，畫面只能人工或截圖驗證。
- 環境注意：這台 Mac 的 xcodebuild 平行測試偶爾會出現「test runner hung before establishing connection」（模擬器 clone 逾時，不是程式問題）。用 `-parallel-testing-enabled NO`，並先讓模擬器開機、App 跑過一次，就能穩定執行。

### 5-3. 觀察到的問題（依嚴重程度）
> 讀程式碼發現，大多沒有在實機重現。標「已確認」的是我抽查過程式碼、確定邏輯如此。

**bug（高：會寫錯資料或明顯誤導）**
1. ~~歷史詳情裡打勾時，完成時間記成「現在」~~ → **已修**：改記那次訓練的結束時間。
2. ~~「全部標為完成」不套用預填、可能存下沒有數字的完成組~~ → **已修**：改成和按 ✓ 一樣用預填值，連預填都沒有的組刪除；確認對話框加了說明。
3. 輔助引體向上的舊紀錄（正數輔助量）在新的負重制下顯示成正負重，影響圖表、個人紀錄、上一次和建議重量。這是 CHANGE_06「舊資料不轉換」的直接後果，待決定是否轉換。
4. ~~設定頁和編輯動作頁的休息秒數說明是舊規則~~ → **已修**。

**bug（中）**
5. ~~「結束並開始新的」沒有停掉休息倒數~~ → **已修**（首頁「結束並建立新菜單」同樣修正）。舊訓練被整筆刪除時仍沒有提示。
6. 歷史詳情的「上一次」和灰字預填取的是「本次以外最新的一次」，所以舊訓練會顯示比它更晚的紀錄。
7. 首頁「結束並建立新菜單」會先結束目前的訓練才開建立菜單。這時在建立菜單按「取消」，原本的訓練已經結束，沒打勾的組也已刪除。
8. ~~建立菜單第 1 步的順序預覽永遠顯示「拉」~~ → **已修**：預覽依預設主項決定。
9. CHANGE_04 舊角色的卡片換動作時，一律當成「下肢輔助」格，所以上肢的舊卡（例如舊的臥推）也只會出現下肢候選。只影響更新前開始的訓練。
10. 首頁「最近 30 天」口徑不一：組數和單邊／爆發用 31 個日曆日、只算已結束的訓練；有氧天數用 30 個日曆日、包含進行中訓練。

**bug（低）**
- 計時器選單的預設秒數取最後一張卡（常是有氧的 60 秒），不是目前在做的動作。
- 數據分頁的 kg/lb 切換會改全 App 的單位設定。
- 重名檢查不忽略大小寫和空白，也不比對別名。
- 首頁長條如果對應的分類只剩封存動作或被篩選掉，點了沒有反應。
- 主項紀錄或篩選沒有結果時，部分卡片沒有空狀態文案。
- `RootView` 的 `#Preview` 沒有 modelContainer，可能跑不起來。
- 小工具 target 裡「開始訓練」intent 的實作是空的。照設計會在 App 程序執行，但沒有實機驗證過控制項真的會導向建立菜單。
- DEBUG 預覽頁的「完成這組」是真的 intent 按鈕，在預覽頁點下去會作用在真實的進行中訓練（只影響 DEBUG）。
- 換主題會用 `.id(theme)` 重建整棵畫面：導覽路徑、捲動位置、篩選全部重置。DEBUG 版還會重跑啟動參數（例如跳回指定分頁）。

**重複的程式碼**（重點，完整清單見 4-4）
- `finish` 邏輯有兩份：`WorkoutActions` 和 `SetLogic.finish`。後者只有測試在用，所以測試沒涵蓋實際執行的路徑。
- 欄位轉文字的 switch 在 SetRow 和 WorkoutEditor 各寫一份；封存切換在動作庫的左滑和長按各寫一份；sheet 骨架重複。
- `ActivityCalendar.dailyCounts` 只有測試在用（首頁自己算），等於 dead code。
- `-openExercise` 和 `-openDetail` 效果相同，`DebugDetailRoute` 是多餘的。

**過大的檔案**
- `HomeView.swift` 488 行、8 個型別：各卡片在 body 裡直接做統計。
- `Backup.swift` 487 行：備份、seed 匯入、動作庫補充、共軛動作表、說明匯入全在一起。
- `PlanBuilder.swift` 432 行。
- `WorkoutEditor.swift` 425 行：編輯器、3 個 sheet、3 個 alert、鍵盤列、草稿、AdviceLine、RoleBadge。
- `PlanFlowView.swift` 397 行、11 個型別（含 3 個共用元件）。
- `ExerciseDataTab.swift` 365 行。

**狀態管理**
- `WorkoutEditor` 有 11 個 @State，換動作要兩段狀態，備註要兩個變數。
- 開始訓練的入口分散：註解說 `requestStart` 是唯一入口，但建立菜單直接呼叫 `WorkoutActions.start`，首頁也自帶一份衝突對話框。
- 用固定的 600 ms 延遲等全螢幕關閉再開 sheet。
- 多處 `try? context.save()` 把錯誤吞掉，只有合併會顯示錯誤。
- 說明編輯每次 onAppear 都重新載入，編輯動作卻只載入一次，兩者做法不一致。
- 每個按鍵都存檔一次（`context.save()`）。

**命名不一致**
- 空標題的替代文字有三種：「訓練中」「空白訓練」「訓練」；標題空白時刪除確認會顯示「刪除「」？」。
- 「N 次」有兩種算法（trainingCount 和 completedItems.count）。
- 動作有兩個筆記欄位：「備註」（note，只在編輯表單看得到）和「我的筆記」（myNotes）。
- 動作詳情有兩個都叫「編輯」的按鈕：右上開動作設定，說明分頁裡開說明編輯。
- 選單寫「從 Apple Watch 帶入」，sheet 標題寫「Apple Watch 紀錄」；`Views/Log/` 資料夾只放了這一個檔案。
- 檔名 `WorkoutCoordinator.swift` 裡還放了訓練中橫條畫面。
- 過期註解或範例文字有幾處：小工具範例還寫「上半身」；預覽頁參數的列舉不完整。

**效能疑慮**（資料量：約 250 次訓練、600 筆以上的動作紀錄；目前實際使用不卡，但會隨資料成長）
- 首頁每次 body 都重算整份訓練快照、所有動作的「最後日期」（每次都攤平所有組）、30 天統計和主項紀錄。捲動時切換分頁列也會觸發整頁重算。
- 訓練中畫面每輸入一個字，就為每張卡重新掃描歷史，算上一次、建議重量和預填值。
- 動作庫和新增動作在排序時反覆計算訓練次數和最後日期。
- 設定頁每次出現都在主執行緒產生一份完整的備份 JSON。
- 4 個分頁各有一個訓練中橫條，各自有 @Query 和每秒更新的 TimelineView。

### 5-4. 已知但還沒修的問題
- 5-3 的 bug（高）3、（中）6、7、9、10，以及（低）各項。（高）1、2、4 和（中）5、8 已在彙整後修正。
- 輔助引體向上的舊紀錄要不要轉成負數：等使用者決定。這會改寫紀錄，需要先確認。
- 分頁列滑動隱藏的修正（commit `c3c6fee`）只在模擬器用程式捲動驗證過，實機手感待確認。
- SPEC.md 的「初始資料」段落、`tools/theme_previews/` 截圖已經過期。
- 小工具快照：App 更新後第一次開啟前，舊格式的快照讀不出來，小工具會短暫顯示「還沒有紀錄」，開一次 App 就恢復（設計上接受）。

---

## 6. 畫面截圖
- **略過**：專案沒有 UI test target，只有單元測試 target `LiftLogTests`，所以沒有新增 UI 測試，也沒有產生 `tools/screens/`。
- 依指示沒有為了截圖修改 App 程式碼。
- 既有的參考圖：
  - `tools/widget_previews/`：小工具、鎖定畫面、即時動態、動態島、控制項，用 DEBUG 預覽頁截的。
  - `tools/theme_previews/`：舊的 5 個主題，已過期。
  - `tools/icon_concepts/`：icon 候選。
- 如果之後要自動截圖，有兩個選擇：
  - 新增一個 UI test target。這需要改 Xcode 專案設定。
  - 不改程式碼，改用既有的 DEBUG 啟動參數（`-startTab`、`-openPlan -planStep 2`、`-demoWorkout`、`-openDetail 臥推`、`-widgetGallery …`）配合 `simctl io screenshot` 截圖。用這個方式可以截到首頁上半、建立菜單兩步、訓練中、動作庫、動作詳情、設定上半和小工具預覽；需要捲動才看得到的區塊截不到，因為模擬器沒有觸控操作。
