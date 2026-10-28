# LiftLog 現況報告（STATUS）

> **CHANGE_07～09 的資訊架構重整已收斂**：三次的收斂標準都通過，CHANGE_09 的實機確認也全部通過。收斂時的版本打了 git tag `v1.0-ia`（`f4ba90c`）。
>
> 觀察到、還沒處理的三項待辦（細節在 `tools/CHANGE_09_REPORT.md` 第 2 節）：
> 1. **灰格子的計算口徑**：日曆的灰色格子（有氧與其他）有的算進次數、有的不算。「只有有氧的訓練也算」關閉時，只有有氧的日子照樣上色但不算；只有核心或補強的日子算。（第 15、16 條）
> 2. **每週目標沒有進備份**：每週目標和「只有有氧的訓練也算」存在 UserDefaults，匯出的 JSON 沒有這兩個設定，重裝後要重新設定。（第 11 條）
> 3. **平均值涵蓋一段沒畫出來的週**：訓練頻率卡只畫 12 條（含本週），平均用本週之前的 12 個週或月，最舊的那一段算進平均但沒有畫出來。（第 2 條）

- 更新時間：2026-10-28，對應 CHANGE_10 完成後的 main（commit `4d6cadf` 之後的文件 commit）。上一版是 CHANGE_09 完成時。
- CHANGE_10（實機回饋修正、首頁日曆改版、鍵盤收合與點擊提示統一）在 `v1.0-ia` 之後，完整結果在 `tools/CHANGE_10_REPORT.md`。
- 對象：負責 review 和規劃、看不到程式碼的人。內容根據實際程式碼、建置、測試與模擬器截圖整理。
- 平台：iOS 26、SwiftUI＋SwiftData，App 只給自己用，用免費 Apple ID 安裝。
- 規模：App＋共用＋小工具約 12,400 行 Swift，單元測試約 4,100 行（249 個）、UI 測試約 500 行（21 個）。
- CHANGE_07 開始前的版本打了 git tag `before-change07`（`6f72de3`）。
- 各次的完整驗收結果、自行決定的事項和實機確認清單在 `tools/CHANGE_07_REPORT.md`、`tools/CHANGE_08_REPORT.md`、`tools/CHANGE_09_REPORT.md`、`tools/CHANGE_10_REPORT.md`。

---

## 1. 進度總覽

### 1-1. 文件來源
- CHANGE_06～10 的原文在 `tools/changes/`（從對話紀錄還原）；CHANGE_01～05 的原文不在 repo 裡，也還原不了，重點整併在 `SPEC.md`（開頭有每份 CHANGE 的一行摘要）。專案的固定規則在根目錄的 `CLAUDE.md`。
- 本節依 commit 訊息的節號加上目前的 `SPEC.md` 對照判斷。

### 1-2. 各份 CHANGE 狀態

| 文件 | 節（依 commit） | 狀態 | 說明 |
|---|---|---|---|
| 初版規格 | Phase 1–8 | 完成（多數已被後續取代） | 單筆紀錄頁、今日分頁等在 CHANGE_02 移除 |
| CHANGE_01 | 怪獸訓練分類、UUID、標籤、別名、合併、訓練日曆 | 完成 | |
| CHANGE_02 | phase 1–5、8 | 完成 | 訓練 → 動作 → 組；訓練分頁在 CHANGE_07 改成「歷程」 |
| CHANGE_02 | phase 6、7 | 無法判斷 | 沒有對應 commit，需要原文確認 |
| CHANGE_03 | 1-1～5-2 | 完成 | 動作庫排序與篩選在 CHANGE_07 改寫 |
| CHANGE_04 | 1–7 | 完成，大部分被 CHANGE_06／07 取代 | |
| CHANGE_05 | 0、2–7 | 完成 | 小工具點擊導向與＋在 CHANGE_07 D-3 改寫 |
| 10/26 優化 | 主題、icon、簽署到期日、右下角＋ | 完成；右下角＋在 CHANGE_07 移除 | |
| CHANGE_06 | §1–§7 | 完成 | 首頁的主項紀錄、推拉比搬到「歷程 → 統計」 |
| STATUS 修正 | 5 個 bug（`6f72de3`） | 完成 | |
| CHANGE_07 | A 遷移與單一入口、B 今天／動作庫／設定、C 歷程與摘要浮窗、D 統計、體重、小工具＋、規則 7 | 完成 | 收斂標準都通過；細節見報告 |
| CHANGE_08 | §1 編輯時沒打勾的組、§2 歷程底部跳動、§3 訓練頻率長條圖、§4 日曆部位顏色與標籤、§5 即時動態版面、追加：收起鍵盤 | 完成 | 收斂標準都通過；第 3、10 條被 CHANGE_09 §0 改掉（報告裡有註記） |
| CHANGE_09 | §0 CHANGE_08 的修正、§1 每週目標設定、§2 訓練次數的規則、§3 首頁日曆的達標小點與標題列、§4 訓練頻率卡的目標線 | 完成；§3 的小點和標題列在 CHANGE_10 §2 拿掉 | |
| **CHANGE_10** | §0-1 圖表擋住捲動、§0-2 分頁列收起一致、§0-3 捨棄訓練與 alert、§0-4 動態島經過時間、§0-5 DE 建議重量、§0-6 上一次、§0-7 只顯示角色、§1 鍵盤收合、§2 首頁日曆、§3 訓練狀態浮窗、§4 點擊提示統一 | **完成** | 收斂標準 G1、G2、S1–S7、V1–V8 都通過；0-1、0-2、0-5、0-6 的原因見報告第 2 節 |

### 1-3. 實作和文件不一樣的地方
CHANGE_10（完整清單在 `tools/CHANGE_10_REPORT.md` 第 3 節）：
- 分頁列：可捲動範圍短的畫面底部區域縮小（中間至少留 48 pt）；切換後 0.35 秒內的位移不算；往下滑進底部區域、已經連續 24 pt 時先隱藏（出現照樣不在底部切換）。
- 動作詳情的折線圖點一下改成選取，「打開這次訓練」另外一個按鈕；有氧、體重卡也加了選取；主項進步的迷你折線沒有自己的選取（整列可點）。
- DE 建議重量的基準用換算表預設的「估算 1RM」（詳情頁的基準沒有存下來）；有建議重量時每一組都預填它。
- ME、DE 主項的「上一次」來自其他角色時只顯示，不拿來預填、不決定組數。
- 訓練中的鍵盤列（-2.5／+2.5／+5、下一格、完成）是 CHANGE_02 就有的，保留。
- 點訓練狀態的輪替列：先關掉訓練狀態，再打開摘要浮窗。
- 主題的預覽方塊和小按鈕照舊用縮小變淡的回饋。

CHANGE_09（完整清單在 `tools/CHANGE_09_REPORT.md` 第 2 節）：
- 「完全沒有紀錄時預設 3」解讀成「近 12 個已經過完的週裡沒有紀錄」：只有本週或很久以前有紀錄時也是 3（不會變成 1）。
- 「只有有氧的訓練也算」關閉時，只有有氧的日子在日曆上照樣上色，只是不算進次數；只有核心或補強的日子算。
- 訓練頻率的長條還是 12 條；平均用的 12 個已經過完的時段裡，最舊的那一段沒有畫出來。
- 「有氧與其他」也用在訓練頻率卡的圖例；日曆圖例右邊加了「● 達標」（CHANGE_10 §2 拿掉）。
- 底部留白：查到訓練中橫條的高度原本就沒有算進去（內容最後一段會被橫條蓋住），現在直接量橫條的上緣。

CHANGE_08（完整清單在 `tools/CHANGE_08_REPORT.md` 第 3 節）：
- 頂端回彈時分頁列一律出現（快速滑回頂端可能跳過頂端 24 pt 那一段）；底部回彈和距離底部 80 pt 以內照規格不切換。
- 只有核心或補強（沒有上下肢）的訓練歸在「有氧」那個中性色（CHANGE_09 起圖例寫「有氧與其他」）。
- 訓練頻率的全身在長條上用兩色斜紋（細長的長條沿對角線分一半會像兩段疊在一起）；日曆格子照規格沿對角線分。
- 即時動態的字級最大到 large，才能保證不超過 160 pt。
- 沒打勾的組「填了數字」指使用者輸入過任何數字；標為完成時和直接按 ✓ 一樣用灰字預填補齊，補了還不夠完成的不算。

CHANGE_07（完整清單在 `tools/CHANGE_07_REPORT.md` 第 2 節）：
- 輔助重量轉負數的分界日用 2026-10-26（CHANGE_06 上線日），之後的正數視為真的加重。
- 遷移沒有要改的資料時不寫自動備份。匯入備份（從 JSON 匯入或還原自動備份）後，備份產生時還沒套用的遷移會再跑一次，不看「只執行一次」的旗標（執行規則 7，依備份檔的 `migrations` 欄位判斷）。
- 「已有進行中的訓練」時不再提供「加入目前的訓練」，只有「繼續目前訓練／建立新菜單」。
- 統計（上次日期、次數、近 30 天）只算已結束的訓練；歷程的紀錄不列進行中的訓練。
- 主項進步只列 90 天內有紀錄的主項，其他寫一行數量。
- 摘要浮窗的時間固定 24 小時制。

### 1-4. git log 摘要（共 89 筆，新 → 舊；不含這次的文件 commit）
```
4d6cadf CHANGE_10 §5: UI test target links AppIntents so the build has no warnings
42a9614 CHANGE_10 §2: the Today calendar card opens 訓練狀態
2100e24 CHANGE_10 §0-2 follow-up: settle after a toggle; a long enough downward run hides on entering the bottom zone
8034503 CHANGE_10 §3: 訓練狀態 sheet with this week and the rotation
8cbb631 CHANGE_10 §4: whole cards and rows are tappable with one press style; no chevrons
e045137 CHANGE_10 §1: dismiss the keyboard by tapping outside or scrolling
e0f1ce5 CHANGE_10 §0-7: the workout card title shows only this session's role
704e17f CHANGE_10 §0-6: 上一次 prefers the same role, then any role with a label
a2a3e9f CHANGE_10 §0-5: DE suggested weight is the 60% row of the intensity table
a2b658d CHANGE_10 §0-1/§0-2 follow-up: steadier UI tests
47f1167 CHANGE_10 §0-4: the elapsed time in the expanded Dynamic Island is always complete
3c93dbc CHANGE_10 §0-3: discard at the bottom of the workout; alerts everywhere
4266fd0 CHANGE_10 §0-2 follow-up: only a finger drag marks a scroll view as phase-reporting
a8ca6a0 CHANGE_10 §0-2: every scrollable tab screen hides the tab bar the same way
b493657 CHANGE_10 §0-1: charts no longer block scrolling; UI test target
45e6211 STATUS: IA restructuring (CHANGE_07–09) converged, three open items
f4ba90c CHANGE_09: report, SPEC and STATUS updates, verification screenshots
52bd720 CHANGE_09 §4: weekly goal on the training frequency card
7260943 CHANGE_09 §3: weekly goal on the Today calendar
235e9e5 CHANGE_09 §1: weekly goal setting
8059bab CHANGE_09 §2: one training-count rule for the whole app
71b8aac CHANGE_09 §0: fixes to CHANGE_08
81de3d2 CHANGE_08: report, SPEC and STATUS updates, verification screenshots
4a96bd1 CHANGE_08 extra: a way to dismiss the keyboard on every input
6848df7 CHANGE_08 §5: fixed-height Live Activity layout under the 160 pt limit
e592870 CHANGE_08 §4: region-colored training calendar with a peek label
dc6191a CHANGE_08 §3: training frequency card as stacked weekly and monthly bars
f86a034 CHANGE_08 §2: stop the tab bar from toggling in a loop at the bottom of lists
25c0ede CHANGE_08 §1: ask to complete filled but unchecked sets when finishing an edit
b361442 CHANGE_07 rule 7: apply missing migrations after importing a backup
b946bc3 CHANGE_07: report, SPEC and STATUS updates, final screenshots
19c689c CHANGE_07 verification: demo and empty data, empty states, fixes from screenshots
0d647b7 CHANGE_07 D: stats cards, body weight, widget plus button and today link
eb8f17f CHANGE_07 C: 歷程 tab, summary sheet actions, editor times, backfill, purpose titles
080fe26 CHANGE_07 B: Today, library and settings hierarchy, StatsCache, shared components
780e89c CHANGE_07 A: migrations with auto-backup, WorkoutLauncher, fewer entry points
6f72de3 Fix five bugs from STATUS review
a356646 CHANGE_06: conjugate (ME/DE) library and plan builder
（更早 51 筆見上一版 STATUS 或 `git log`）
```

---

## 2. 畫面清單

> 共通：顏色都走主題 token（`Theme.*`），App 固定深色；按鈕高度和膠囊高度走 `Metrics`（50／38）。
> 層級：第 1 層分頁、第 2 層 push、第 3 層唯讀 sheet。

**2-1. 分頁殼與訓練中橫條**（`Views/RootView.swift`、`Views/Workout/WorkoutCoordinator.swift`）
- 4 個分頁：今天、歷程、動作庫、設定（`AppTab` enum）。有進行中的訓練時，分頁列上方有「訓練中 m:ss」橫條，點一下展開全螢幕訓練。
- RootView 也負責：建立菜單 sheet、訓練摘要浮窗、全螢幕訓練與完成摘要、開始訓練的確認對話框、深層連結導向、啟動時的匯入與資料遷移。
- 四個分頁底下所有可以捲動的畫面往下捲隱藏分頁列、往上捲出現（同一個 `.hidesTabBarOnScroll()`；連續 24 pt、底部 80 pt 以內和回彈中不切換，隱藏時版面不變；訓練中橫條照樣顯示）；動作詳情整頁隱藏分頁列。
- 確認一律用置中的 alert；可以點的卡片和列整塊可點、按下時換成按壓色，沒有「›」。

**2-2. 今天**（`Views/Today/TodayView.swift`、`TrainingCalendar.swift`）
- 「下一次」卡（日型、建議主項、動作數與跑步機）→ 建立菜單。
- 訓練日曆：每欄一週、從週一開始，寬度塞滿、不橫向捲動；格子依部位上色（下肢 accent、上肢 upperBody、全身對角分半、有氧與其他淡灰），下面是圖例。整張卡點一下打開「訓練狀態」浮窗（`TrainingStatusSheet`，半高可拉成全高）：本週（天數／目標、組數、下肢／上肢／其他、有氧分鐘、上週同期）和 ME／DE 上下肢四列的輪替狀態（上次幾天前、上次和下次主項、「下一次」標記，點有紀錄的列打開那次的摘要）。
- 「近 30 天」9 個分類的組數長條 → 第 2 層分類待練清單（沒練過的排最前、標「新」）→ 動作詳情。
- 空資料：日曆下寫「還沒有訓練紀錄。點上面的「下一次」建立第一份菜單。」；長條都是 0；訓練狀態每列「還沒練過」。

**2-3. 建立菜單**（`Views/Plan/PlanFlowView.swift`，sheet）
- 第 1 步三個問題（日型、動作數、跑步機）＋「不照建議，自由選動作」；第 2 步每格選動作；「開始訓練」。
- 有進行中的訓練時：進來前先問「繼續目前訓練／建立新菜單」，按開始時才確認結束舊訓練。

**2-4. 訓練中**（`Views/Workout/WorkoutView.swift`、`WorkoutEditor.swift`，全螢幕）
- 標題欄位（自動名稱、恢復自動名稱；return 收起鍵盤）、經過時間、休息計時、動作卡片與組。點動作名稱開唯讀說明 sheet。卡片標題旁只有這次的角色；「上一次」同角色優先，沒有時加角色小字（「40×3・ME」）；DE 速度主項「建議 55 kg（60%）」並灰字預填。最底部紅字「捨棄訓練」（置中的確認）。
- 完成後的摘要（`WorkoutSummaryView`）有選填的「今天體重」，輸入時捲到中間。全 App 的鍵盤：點空白處、往下捲、按主要按鈕都會收起。

**2-5. 歷程**（`Views/History/HistoryView.swift`、`HistoryStatsView.swift`）
- 分段「紀錄｜統計」；右上 ⋯「補登訓練」。
- 紀錄：依月份分組「2026 年 10 月・19 次」，每列日、星期、名稱、時長與動作數 → 摘要浮窗。
- 統計：主項進步、體重、有氧、訓練頻率（週｜月的長條圖，以天為單位、依部位疊色；虛線平均只算過完的週或月；「週」有一條實線是每週目標；標題列「本週 2/3・近 12 週平均 M 次」）、平衡五張卡。有氧、訓練頻率、體重的圖表點一下選取、按住 0.2 秒後拖曳；上下滑交給捲動。

**2-6. 訓練摘要浮窗**（`WorkoutSummarySheet.swift`，第 3 層 sheet）
- medium／large；名稱、日期、「18:30–19:45・75 分」、體重；每個動作的角色、新紀錄、組；備註。
- ⋯：編輯（全螢幕 `SessionEditorView`：名稱、日期、開始與結束時間、未記錄時間的「設定時間」、動作卡片；按「完成」時有填了數字但沒打勾的組先詢問「把 N 組標為完成／保持未完成／繼續編輯」）、再做一次、刪除。

**2-7. 補登訓練**（`HistoryView.swift` 的 `BackfillSheet`）
- 日期、開始、結束時間 → 照建議建立菜單／自由選動作 → 建立已結束的訓練並進入編輯。

**2-8. 體重**（`BodyWeightViews.swift`）
- 體重卡（最新、近 30 天變化、範圍、折線＋7 日平均）、記錄體重 sheet（同一天覆蓋前確認）、從健康 App 帶入（多選）。

**2-9. 動作庫**（`Views/Library/`）
- 第 1 層：9 個分類列（數量、最久沒練、未練過數）＋已封存；搜尋直接列結果。
- 第 2 層分類清單：排序（4 種，記住）與篩選（主／單／爆）popover；左滑封存、長按合併／封存／刪除。
- 動作詳情（`Views/Detail/`）：數據／說明／歷史；⋯「編輯動作」、說明分頁「編輯說明」；紀錄與圖表的點 → 摘要浮窗。

**2-10. 設定**（`Views/Settings/`）
- 5 列：外觀（主題）、單位與進位、訓練（每週目標 1–7 次、只有有氧的訓練也算、自動休息、即時動態）、備份與還原（匯出、匯入、自動備份清單）、關於（版本、簽署到期）。

**2-11. 小工具與系統畫面**（`Shared/LastWorkoutViews.swift`、`LiftLogWidgets/`）
- 小型小工具：右上角＋（建立菜單，訓練中隱藏）；點其他地方 → 訓練中打開訓練，否則回到今天。
- 鎖定畫面三種：不放按鈕，點擊導向同上。控制項、App Shortcut 不變（開始訓練走同一個入口）。
- 即時動態（`Shared/WorkoutActivityViews.swift`）：鎖定畫面休息和非休息一樣高（150 pt，上限 160），每列固定高度、文字一行截斷、字級最大到 large；動態島展開同樣的層級（約 140 pt），經過時間一定完整（放不下時系統移到下一行）。

---

## 3. 導覽地圖
```
LiftLogApp → RootView（TabView，固定深色）
├─ [今天] TodayView（NavigationStack）
│   ├─「下一次」卡 → sheet 建立菜單 PlanFlowView（第 1 步 → 第 2 步 →「開始訓練」→ 訓練中）
│   ├─ 日曆的某一天 → 浮出標籤（不導向）
│   └─ 近 30 天的分類 ─ push → 分類待練清單 ─ push → 動作詳情
├─ [歷程] HistoryView（NavigationStack）
│   ├─ 紀錄 → 摘要浮窗
│   ├─ 統計 → 主項 ─ push → 動作詳情；體重卡 → sheet 記錄體重 → sheet 從健康 App 帶入
│   └─ ⋯ 補登訓練 → sheet 第 1 步 → 建立菜單或自由選動作 → 編輯（全螢幕）
├─ [動作庫] LibraryView（NavigationStack）
│   ├─ 分類 ─ push → 分類清單（排序／篩選 popover）─ push → 動作詳情
│   ├─ 已封存 ─ push → 已封存清單
│   ├─ 搜尋結果 ─ push → 動作詳情
│   └─ ＋ → sheet 新增動作；長按 → sheet 合併到…
├─ [設定] SettingsView ─ push → 外觀／單位與進位／訓練／備份與還原／關於
├─ 各分頁底部：訓練中橫條 → 訓練中
├─ sheet：摘要浮窗 WorkoutSummarySheet（任何一層都能開；⋯ 編輯 → 全螢幕 SessionEditorView）
└─ fullScreenCover：訓練中 WorkoutView（或完成後的 WorkoutSummaryView）
    ├─ sheet → 新增動作、換動作、從 Apple Watch 帶入、動作說明（唯讀）
    └─ 完成 → 確認 → 摘要（今天體重）→ 關閉

開始訓練：只經過 WorkoutLauncher（下一次卡、自由選動作、再做一次、補登、liftlog://new、控制項、Siri、小工具＋）
深層連結 liftlog://（onOpenURL、intent、App Group 裡的待處理連結 → DeepLinkRouter → RootView）
├─ new：建立菜單（有進行中的訓練時先問）
├─ workout：打開進行中的訓練；沒有就等於 today
└─ today：切到今天分頁、回到第 1 層
```

---

## 4. 架構

### 4-1. 目錄結構（行數）
```
LiftLog/                     App target
  LiftLogApp.swift           進入點                                              18
  Models/   Models.swift、Enums.swift                                         381
  Logic/    30 檔：建立菜單、角色、訓練操作、統計快取、資料遷移、體重、時間編輯、部位與訓練頻率、訓練次數與每週目標、訓練狀態等  3,651
  Data/     Backup.swift（備份、seed 匯入、動作庫補充、說明匯入）、seed.json、ExerciseGuides.json  498＋JSON
  Theme/    Components.swift（共用元件、Metrics、按鈕和按壓樣式、分頁列自動隱藏）、KeyboardDismiss.swift（收起鍵盤）、
            ChartSelection.swift（圖表的選取手勢）、RegionStyle.swift（部位顏色、圖例、標籤）  672
  Intents/  intent 的 perform、App Shortcut                                     70
  Views/    RootView 257、Today 383、History 1,276、Plan 380、Workout 1,506、Library 589、
            Detail 639、Settings 503、Log 101、Debug 397（只在 DEBUG）
Shared/     App 和小工具共用：主題、日型、部位、快照、深層連結、待處理連結、RelativeDay、即時動態、intent  917
LiftLogWidgets/  小工具 target：小工具、即時動態、控制項                           155
LiftLogTests/    35 檔，Swift Testing                                         4,125
LiftLogUITests/  7 檔＋共用，XCUITest（CHANGE_10）                                488
tools/      parse_log.py、migration_review.py、pixel_compare.swift、icon 產生器、截圖（screens/final、change08、change09、change10）
```

### 4-2. 資料模型（SwiftData，`LiftLog4.store`，沒有改結構以外的東西）
- **Exercise**：id、name、category、tags、aliases、englishName、equipment、logType、note、isArchived、restSeconds、meRotation／deRotation、說明欄位、myNotes → sessionItems。
- **WorkoutSession**：id、startedAt、endedAt、title、**isTitleCustom（CHANGE_07，預設 false）**、note、hasTime、dayType、region、modeID → items。
- **SessionExercise**：id、session、exercise、order、note、role → sets。
- **SetRecord**：id、order、kind、weightKg、reps、incline、speed、minutes、seconds、isCompleted、completedAt、healthWorkoutID。
- **BodyWeight**：date、kg（CHANGE_07 有畫面了，同一天一筆）。
- **其他持久化**：
  - UserDefaults：`theme.id`、`weightUnit`、`autoRestTimer`、`liveActivity.enabled`、`round.*`、`restTimer.*`、`library.sort`、`history.segment`、`history.frequencyPeriod`、`weeklyGoal.goal`、`weeklyGoal.cardioOnlyCounts`。
  - 一次性旗標：`libraryAdditions.v1/v2`、`conjugateLibrary.v1`、`guidesImported.v2`、`migration.assistToNegative`、`migration.autoTitles`。
  - Documents/AutoBackups：遷移前的自動備份。
  - App Group：小工具快照 `widgetSnapshot.v1`、小工具＋的待處理連結 `pendingDeepLink`。
- **備份 JSON**：version 6，多了 `migrations`（已經套用的遷移）；可以讀 v2（seed）～v5。匯入後補做檔案裡沒套用的遷移，沒有這個欄位的視為都沒套用。

### 4-3. 服務與狀態
- `LiftLogStore.container`：唯一的 ModelContainer，畫面和 intent 共用 mainContext。
- `WorkoutLauncher`（@Observable，environment）：開始訓練的唯一入口，管建立菜單的 sheet、繼續／新菜單的問題、結束舊訓練的確認、補登、再做一次。
- `WorkoutCoordinator`（@Observable）：目前分頁、今天的導覽路徑、全螢幕或縮小、完成摘要、摘要浮窗要開哪一次、訓練狀態浮窗。
- `StatsCache.shared`（@Observable）：今天、動作庫、統計要用的數字（CHANGE_08 加上每天的部位與名稱、訓練頻率的週和月；CHANGE_09 加上算進次數的日子、每週天數、每週目標的預設值；CHANGE_10 加上訓練狀態）；存檔後 0.3 秒重算，「只有有氧的訓練也算」改變時也重算。
- `TrainingCount`／`WeeklyGoal`（`Logic/WeeklyGoal.swift`，CHANGE_09）：全 App 唯一的訓練次數規則（週一開始、以天為單位、只算有完成組的已結束訓練、只有有氧的處理）和每週目標（預設值；CHANGE_10 拿掉了達標和連續週數）。`TrainingStatus`（`Logic/TrainingStatus.swift`，CHANGE_10）：訓練狀態浮窗的本週、上週同期、輪替，全部呼叫共用函式。
- `DataMigrations`／`AutoBackup`：啟動時的遷移與遷移前備份；`DataMigrations.restore` 是匯入和還原的唯一入口（還原後補做沒套用的遷移）。
- `RestTimer.shared`、`WorkoutService.shared`、`WorkoutActions`、`DeepLinkRouter.shared`、`SnapshotWriter.shared`、`LiveActivityController.shared`：同 CHANGE_06。
- 純邏輯（可單元測試）：PlanBuilder、Roles、SetLogic（含 SessionTitle）、SessionTimeEdit、BodyWeightLog、RelativeDay、ExerciseStats、Recency、LibrarySort、TabBarAutoHide、BottomInset、DayRegion、TrainingFrequency、TrainingCount、WeeklyGoal、TrainingStatus、IntensityTable、CalendarGrid、ProvisioningProfile。

### 4-4. 共用元件
- `Theme/Components.swift`：`.card()`、ScreenHeader、ThinBar、Chip、AccentChip、`Metrics`、PrimaryButton／PrimaryButtonLabel、FilterCapsule、ElapsedTimeText、`.pressable`（小按鈕）、`TapSurfaceStyle`（`.tapCard`／`.tapRow`／`.tapListRow`）和 `TapListRow`（CHANGE_10：可以點的卡片和列）、`.hidesTabBarOnScroll()`。
- `Theme/KeyboardDismiss.swift`：`dismissKeyboard()`、`KeyboardDismissOnTap`（點空白處收起鍵盤）。`Theme/ChartSelection.swift`：`chartDateSelection`、`PressThenDragGesture`（圖表的選取）。
- `Theme/RegionStyle.swift`：`DayRegion.fill／barFill`、RegionLegend、PeekLabel（圖表共用）。
- `Shared/RelativeDay.swift`：今天／昨天／N 天前（App 和小工具共用）。
- 共用畫面：`WorkoutSummarySheet`、`SessionTitleField`、`ExerciseInfoSheet`、`LibraryExerciseRow`、`TrainingCalendar`（只剩今天在用；CHANGE_10 起整張卡是一個按鈕）、`TrainingStatusSheet`。
- 上一版列出的重複（大膠囊按鈕 4 種高度、3 種篩選膠囊、3 份經過時間、4 處天數格式、2 份衝突對話框）都已合併。

---

## 5. 品質狀況

### 5-1. 建置
- Debug（含測試）、Release（模擬器）、Release（iphoneos，不簽署）的 clean build：**0 個 warning、0 個 error**。

### 5-2. 測試
- **270 個全部通過，0 失敗**：單元測試 249（35 檔）、UI 測試 21（7 檔），iPhone 17 Pro 模擬器，`-parallel-testing-enabled NO`。
- CHANGE_10 新增：UI 測試 target `LiftLogUITests`（統計頁從圖表往上捲、圖表點選、各分頁收起分頁列、訓練中橫條、捨棄訓練、鍵盤收合、模擬器上的動態島、訓練狀態）；單元測試 TrainingStatusTests 6（上週同期的範圍、本週組數、輪替和建立菜單一致、14 天警示）、PlanTests（DE 建議重量＝換算表 60%）、WorkoutActionsTests（上一次同角色優先、捨棄要確認）、TabBarAutoHideTests 3（短頁面、切換後的跳動、稀疏的位置）、ThemeTests（按壓色）。拿掉連續達標 5 個、日曆標籤 2 個。
- CHANGE_09 新增：TrainingCountTests 10（以天為單位、只算已結束而且有完成組、只有有氧的開關、週一開始、跨年那一週、連續達標 4 種情況、改目標後重新判斷）、WeeklyGoalTests 5（預設值有紀錄和沒紀錄、改過之後不再自動計算）、WorkoutActionsTests（「繼續編輯」不改資料）、TrainingRegionTests（平均排除本週和本月）、TabBarAutoHideTests 3（橫條消失後留白變小、分頁列切換留白不變）。
- CHANGE_08 新增：WorkoutActionsTests（T1 編輯時沒打勾的組）、TabBarAutoHideTests（T2 底部回彈序列、80 pt、連續 24 pt、頂端回彈）、TrainingRegionTests（T3 週和月、部位、平均、只算已結束；部位合併）、ActivityCalendarTests（T4 格子對日期、標籤文字）、ThemeTests（upperBody 的色相和亮度）、WidgetSnapshotTests（即時動態高度）。
- CHANGE_07 新增或改寫：DataMigrationsTests 6、WorkoutLauncherTests 6、StatsCacheTests 3、SessionTitleTests 6、SessionTimeEditTests 4、BodyWeightLogTests 6、DeepLinkTests 9、WorkoutActionsTests（上一次只取之前的訓練）、LibraryTests、ExerciseListsTests、FilterTests、RestTimerTests（改用隔離的設定和安靜的通知）。
- 畫面用 DEBUG 啟動參數配合 `simctl io screenshot` 驗證（`tools/screens/final/`、`change08/`、`change09/`、`change10/`），需要手勢的畫面用 UI 測試的截圖；歷程捲到底部的穩定性用 `tools/pixel_compare.swift` 比對連拍的像素。

### 5-3. 上一版的問題現在的狀態
**已修（CHANGE_10）**
- 統計頁捲到底部後從訓練頻率圖往上滑沒有反應 → 圖表的長按拖曳手勢擋住捲動，改成共用的選取手勢。
- 動作庫和所有 List 畫面不會收起分頁列 → List 收不到捲動狀態；短頁面、切換時的版面跳動也一起處理。
- 動態島展開時經過時間被裁切 → 不限寬度、先縮小、再移到下一行。
- DE 主項沒有建議重量、「上一次」是「—」 → 角色是 CHANGE_06 才有的，舊紀錄沒有 ME／DE 角色；改用換算表和同角色優先的規則。
- `ActivityCalendar` 的位置換算、`WeeklyGoal.Progress` 等隨功能刪掉。

**已修（CHANGE_09）**
- 訓練中橫條的高度沒有算進底部留白（內容最後一段被橫條蓋住）；橫條消失後留白也不會變小 → 直接量橫條的上緣，消失後重新量。
- 本週沒有紀錄時，訓練頻率的「週」少畫本週那一格 → x 軸一律留 12 段的位置。

**已修（CHANGE_08）**
- 歷程捲到底部卡住並一直跳動（實機回報）→ 分頁列隱藏不再改變可捲動範圍，底部 80 pt 以內和回彈中不切換；另外修正了「最底部」的算法（以前 ScrollView 會差一個 inset）。根本原因見報告第 2 節。
- 編輯過去的訓練只填數字沒打勾，不算進統計 → 按「完成」時詢問。
- 數字鍵盤和多行輸入收不起來（體重等）→ 鍵盤上方的「完成」。
- 即時動態休息時文字被裁掉 → 固定高度 150 pt。

**已修（CHANGE_07）**
- 輔助引體向上的舊紀錄是正數 → 遷移 `assistToNegative` 轉成負數（先自動備份，清單在 `tools/assist_review.txt`）。
- 歷史詳情的「上一次」會拿到之後的紀錄 → 只取那次訓練之前的。
- 「結束並建立新菜單」先結束才開建立菜單 → 改成按「開始訓練」時才確認，取消不動。
- 首頁「最近 30 天」口徑不一 → 統一用 `RecentWindow`（含今天的 30 個日曆日、只算已結束的訓練）。
- 數據分頁的 kg/lb 切換會改全域單位 → 切換移除。
- 首頁長條點了沒反應 → 改成進入分類待練清單。
- 空狀態文案不齊 → 今天、歷程、統計各卡、動作庫都有。
- 開始訓練的入口分散、兩份衝突對話框 → 只剩 `WorkoutLauncher`。
- 小工具的「開始訓練」intent 實作是空的 → 會把連結存進 App Group 讓 App 接手。
- 動作詳情兩個「編輯」按鈕 → 「編輯動作」「編輯說明」。
- 首頁每次 body 重算統計、動作庫排序反覆計算 → `StatsCache`。
- 設定頁每次出現都產生備份 JSON → 只在「備份與還原」頁出現時產生。
- `HomeView.swift` 488 行 → 拆成 TodayView 與共用元件。

**還在（沒在 CHANGE_07 範圍內）**
- CHANGE_04 舊角色的卡片換動作時一律當成「下肢輔助」格（只影響更新前開始的訓練）。
- 計時器選單的預設秒數取最後一張卡。
- 重名檢查不忽略大小寫和空白，也不比對別名。
- `RootView` 的 `#Preview` 沒有 modelContainer。
- DEBUG 預覽頁的「完成這組」是真的 intent 按鈕（只影響 DEBUG）。
- 換主題用 `.id(theme)` 重建整棵畫面，導覽和捲動位置重置。
- `finish` 邏輯兩份（`WorkoutActions.finish`、`SetLogic.finish`，後者只有測試在用）；`ActivityCalendar.dailyCounts`／`level` 只有測試在用；`MainLiftSummary`、`Exercise.homeSummary`（ME 紀錄）沒有人用。
- 深層連結開建立菜單時，如果全螢幕畫面開著，仍用固定 600 ms 等它關掉。
- 多處 `try? context.save()` 吞掉錯誤。
- 4 個分頁各有一個訓練中橫條（各自 @Query 和每秒更新）。
- 過大的檔案：`Backup.swift` 493、`PlanBuilder.swift` 440、`WorkoutEditor.swift` 435 行。

### 5-4. 要在實機確認的事
- `tools/CHANGE_10_REPORT.md` 第 5 節：從圖表位置往上滑（包括平衡卡）、各分頁收起分頁列、點空白處和捲動收起鍵盤、按壓回饋、訓練狀態浮窗的拖曳、實機的動態島。
- `tools/CHANGE_09_REPORT.md` 第 4 節：每週目標的數字、達標小點、訓練頻率的目標線、「只有有氧的訓練也算」、訓練中橫條出現和消失時的底部留白、編輯畫面的「繼續編輯」。
- `tools/CHANGE_08_REPORT.md` 第 5 節：歷程捲到底部的手感、日曆拖曳的觸覺回饋、鎖定畫面休息狀態、動態島、鍵盤的「完成」。
- `tools/CHANGE_07_REPORT.md` 第 4 節：小工具＋、HealthKit 體重權限、真實資料的遷移結果、sheet 的手感。

---

## 6. 畫面截圖
- `tools/screens/change10/`：CHANGE_10 的驗收截圖（V1 首頁、V2 訓練狀態（含空資料）、V3 數字鍵盤、V4 捨棄訓練、V5 DE 主項、V6 動態島（預覽和模擬器上真的動態島）、V7 連拍比對、V8 沒有「›」）。索引在 CHANGE_10 報告第 6 節。
- `tools/screens/change09/`：CHANGE_09 的驗收截圖（V1 首頁、V2 設定、V3 訓練頻率、V4 詢問、歷程穩定性的連拍和比對結果、空資料）。索引在 CHANGE_09 報告第 5 節。
- `tools/screens/change08/`：CHANGE_08 的驗收截圖（V1 每個畫面 5 張連拍和比對結果 `V1_pixel_compare.txt`）。索引在 CHANGE_08 報告第 6 節。
- `tools/screens/final/`：CHANGE_07 的驗收截圖（iPhone 17 Pro 模擬器，seed＋示範訓練；V7 是空資料）。索引在報告第 5 節；今天的日曆和訓練頻率卡已經換成 CHANGE_08 的樣子。
- `tools/widget_previews/`：CHANGE_05 的小工具與即時動態預覽（小型小工具還沒有＋，新的見 `screens/final/V6_widget_small.png`）。
- `tools/theme_previews/`：舊的 5 個主題，已過期。
- `tools/icon_concepts/`：icon 候選。
- 截圖方式：DEBUG 啟動參數（列在 SPEC.md「13. 開發用啟動參數」）配合 `xcrun simctl io <裝置> screenshot`。
