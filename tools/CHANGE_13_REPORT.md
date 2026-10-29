# CHANGE_13 首頁精簡、設定移到右上角、顏色語意與動作庫精簡：最終報告

- 日期：2026-10-29
- 範圍：§0 存原文；§2 首頁精簡成「下一次」和「本週」兩張卡、改用系統的大標題；§1 設定改成「今天」右上角的齒輪打開的 sheet，分頁剩三個；§3 整理顏色的意思（部位色、強調色、不用紅綠燈、對比度、訓練名稱、不只靠顏色）；§4 動作庫第 1 層只顯示動作數。照 prompt 建議的順序 §2 → §1 → §3 → §4，每一節各自 commit，都是建置成功、全部測試通過後才 commit。CLAUDE.md 的執行規則 1～7 照常適用（這次沒有資料遷移，資料模型和備份格式都沒有改）。
- 結果摘要：**四節都完成，沒有遇到「先停下來」的情況**。系統的大標題加兩張卡在兩種狀態下都放得下（沒有訓練時本週卡底部離分頁列 216.5 pt，有附屬列時離附屬列 182.5 pt）。R1 真實資料比對兩個時間點全部一致。
- 驗證環境：Xcode 27.1（`/Applications/Xcode.app`），iPhone 17 Pro 模擬器（iOS 26.5），測試一律 `-parallel-testing-enabled NO`。最後的截圖在乾淨安裝後用 seed＋示範訓練（`-demoData`），空資料（`-emptyData`）放在最後。真實資料只在 R1 比對時匯入，比對完就把 App 從模擬器移除，之後才截圖。
- 文件：`CLAUDE.md`（設計原則改成三個分頁加設定的 sheet；程式慣例加上每個顏色的意思）、`SPEC.md`（開頭摘要、資訊架構、共用元件、點擊提示、今天、訓練狀態、統計快取、訓練中畫面、休息計時器、動作詳情、動作庫、設定、主題配色、深層連結、統計、開發用參數、已移除）、`tools/STATUS.md`、`tools/changes/README.md`（加上 CHANGE_13）已更新；`tools/CHANGE_12_REPORT.md` 第 2 節的大標題和第 4 節附屬列蓋住近 30 天、`tools/CHANGE_10_REPORT.md` 第 3 節的「§2 首頁日曆」加了粗體註記。

---

## 1. 收斂標準的結果

### 建置與測試
| 項目 | 結果 | 驗證方式 |
|---|---|---|
| G1 Debug、Release 0 error 0 warning | **通過** | 最後的程式（`ce82203`）clean build 三種：Debug（含單元測試和 UI 測試 target，`build-for-testing`）、Release 模擬器（`generic/platform=iOS Simulator`）、Release 實機（`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO`），`grep -c 'error:'`、`grep -c 'warning:'` 都是 0。 |
| G2 全部測試通過 | **通過** | 最後的程式乾淨安裝後跑全部測試：**269 個全部通過**、0 失敗。單元測試 242（36 檔）＋UI 測試 27（11 檔＋共用）。CHANGE_12 結束時 258 個：單元新增 11（`TodayCardsTests` 10 個；`ThemeTests` 原本的上肢色 1 個換成部位色和對比度 2 個）、刪掉 2（`ActivityCalendarTests`，日曆刪掉）；UI 新增 2（`SettingsSheetUITests` 1 個；`TodayLayoutUITests` 1 個改成沒有訓練、有訓練 2 個）。 |

G2 要求的新測試：

| 規格要求 | 測試 | 結果 |
|---|---|---|
| 「下一次」卡：沒有訓練 | `TodayCardsTests.nextCardWithoutAWorkoutShowsThePlanDefaults`：預設答案的日型、「1 個動作・跑步機 30 分鐘」、DE 速度主項的建議重量等於建立菜單的 `SlotAdvice.make`；`snapshotKeepsTheSuggestedMainAndItsLogs`：卡片的主項就是建立菜單主項格預設選的那一個，連同它的紀錄 | 通過 |
| 「下一次」卡：有進行中的訓練 | `nextCardWithAnActiveWorkoutShowsThatWorkout`：有進行中的訓練時內容是這次的訓練，不是下一次的建議；UI 測試 `TodayLayoutUITests.testTodayFitsOneScreenWithAnActiveWorkout`：卡片寫「進行中」「繼續」、沒有「主項」，點了打開訓練畫面 | 通過 |
| DE、ME、沒有主項三種主項寫法 | `nextCardWithoutAWorkout…`（DE「主項：臥推（速度）・建議 57.5 kg」）、`mainLineForMaxEffortDynamicEffortAndNoCandidate`（ME「主項：深蹲・做到 3RM」、早安式「做到 5RM」、DE 速度沒有紀錄「主項：深蹲（速度）」、DE（爆）「主項：壺鈴擺盪」、沒有候選「主項：—」、不加跑步機「2 個動作」） | 通過 |
| 本週圓點：依部位上色、只有有氧時是中性灰、今天有外框 | `dotsAreColoredByRegionAndTodayIsMarked`：7 天是週一到週日、依部位、只有有氧的日子是有氧與其他、上週日的訓練不算、只有今天是「今天」、之後的日子是空的；六個主題的下肢、上肢、全身（兩色）、有氧與其他（中性）用的 token；「不以顏色區分」的字。`StatsCacheTests`、`TrainingRegionTests`：快照裡每天的部位（同一天下肢＋上肢是全身、沒打勾的那天沒有顏色） | 通過 | **（CHANGE_14 §1：7 個圓點換成點點日曆，這兩個圓點的測試換成日曆的測試。）**
| 週一和週日的邊界 | `mondayAndSundayBoundaries`：週一 0 點時第一個是今天、其他都是之後；前一天週日屬於上一週。週日晚上最後一個是今天、沒有之後的日子；下一個週一不在這週。`TrainingCountTests.weeksStartOnMonday` 也改成用本週卡的圓點 | 通過 |
| 輪替膠囊：「下一次」分別是四個日型 | `rotationMarksForEachNextDayType`：ME 下肢 → 四個都沒有勾勾；ME 上肢 → 1 個勾勾；DE 下肢 → 2 個；DE 上肢 → 3 個；「下一次」只有一個、後面的不加標記 | 通過 |
| 提醒：14 天不顯示、15 天顯示 | `reminderAfterFourteenDays`（也確認文字「下肢拉已經 15 天沒練」） | 通過 |
| 提醒：好幾個分類時取天數最多的；核心、補強、有氧不列入；從沒練過的不列入 | `reminderPicksTheLongestAndSkipsCoreAccessoryCardioAndNeverTrained`（一樣多天時取分類順序在前的）；`snapshotReminderUsesTheLatestSetOfTheCategory`：分類的最近一次完成組包括封存的動作、用快照的「現在」；本週卡的天數和組數就是訓練狀態的本週 | 通過 |
| 顏色：部位色和強調色、warning 色相差至少 40 度 | `ThemeTests.bodyColorsAreDistinctFromAccentAndWarning`：六個主題的下肢、上肢各自和 accent、warning 的色相差 ≥ 40 度（實際最小 48 度；石墨銀沒有色相，檢查彩度 ≥ 0.35），兩色之間 ≥ 60 度、亮度差 ≤ 0.15、比背景亮 ≥ 0.45 | 通過 | **（CHANGE_14 §2：部位色改成六個主題共用的系統藍、系統橘，這個測試拿掉，改成色相差 60 度和對比度 3:1。）**
| 顏色：次要文字的對比度至少 4.5:1 | `ThemeTests.secondaryTextHasEnoughContrast`：六個主題的 textSecondary 在 background、card、field 上（WCAG 2：6.9、6.3、5.2） | 通過 |
| UI：右上角的齒輪打開設定、能進到第 2 層、能關閉 | `SettingsSheetUITests.testGearOpensSettingsSheet`：齒輪在導覽列右上角；分頁只有三個、沒有「設定」；點齒輪打開設定、進到「外觀」、返回、右上角的關閉按鈕關掉 sheet、回到今天；再打開時是第 1 層 | 通過 |
| UI：首頁在沒有訓練、有進行中的訓練時都一個畫面放得下 | `TodayLayoutUITests` 兩個測試：導覽列是系統的「今天」、兩張卡都在導覽列下面、本週卡整張在分頁列（或附屬列）上方，量到的數字存成附件 | 通過（216.5 pt、182.5 pt，見第 2 節） |

其他改寫的測試：
- `TrainingStatusUITests.testWeekCardOpensTrainingStatus`：以前點日曆卡，改成點本週卡。
- `TabBarMinimizeUITests`：以前用「設定」分頁的按鈕判斷分頁列有沒有縮小，設定不是分頁了，改用「今天」的按鈕（測試停在歷程）。
- `StatsScrollUITests.testDragFromCardioCardScrolls`：平衡卡多了 9 列，捲到底部時有氧卡在畫面上方之外（起點 y = −61），先慢慢往回拖到看得到有氧卡再測。
- `StatsRefreshTests`：以前看「最久沒練」的天數，改看分類最近一次完成組到快照「現在」的天數。

### 程式碼檢查
| 項目 | 結果 | 檢查方式 |
|---|---|---|
| S1 分頁只剩三個，設定分頁的程式已刪除 | **通過** | `AppTab` 只有 today、history、library；`grep` `AppTab.settings`／`case .settings`：0 筆。UI 測試也確認分頁列只有三個按鈕。 |
| S2 ScreenHeader 沒有殘留的使用 | **通過** | `grep ScreenHeader`（App、共用、小工具、測試）：0 筆，元件已刪掉。 |
| S3 首頁的大日曆、近 30 天卡、today.category 的程式和測試都已刪除 | **通過** | `grep -E 'TrainingCalendar\|ActivityCalendar\|CalendarGrid\|RecentSetsCard\|RecentVolume\|CategoryTodoList\|TodoRow\|todayCategory\|todayPath\|recentSetsCard\|訓練日曆\|DayStat'`：0 筆。清單在第 3 節。 |
| S4 綠色和黃色的狀態色沒有殘留的使用 | **通過** | `grep` `Theme.done`／`p.done`／`Theme.warning`：done 只剩完成的組（打勾、整列底色、主題預覽的完成列、即時動態的「完成這組」）；warning 只剩提醒和警示（本週卡的提醒、訓練狀態超過 14 天、超過 60 天沒練、「拉偏少」「0 沒練」、簽署快到期、結束時間錯誤、同一天已有體重、安全提示、封存的滑動按鈕）。沒有用綠色或黃色表示好壞的地方。 |
| S5 本週卡、訓練狀態浮窗、平衡卡的數字都來自共用函式 | **通過** | 本週卡的「N 天・N 組」是 `StatsSnapshot.trainingStatus.thisWeek`（`TrainingStatus.make` → `TrainingCount.count`、`PlanHistory.setCount`），和訓練狀態浮窗的本週同一個值；本週卡的「下一次」是 `nextPlan.dayType`（`PlanDefaults.answers`，「下一次」卡同一個）；圓點是快照的 `dayRegions`（`DayRegion.of`／`merged`，訓練頻率同一套）；提醒用 `TrainingStatus.isStale` 的門檻和 `Recency.daysSince`；平衡卡的 9 列是 `recentSets`（`PlanHistory.setCount(within:)`，原本近 30 天卡的函式），推拉比是 `balance`。畫面裡沒有自己的計算（`WeekCard.days`／`rotation` 只排版快照的資料）。 |

另外：
- 開發用參數的腳本檢查（列出所有 `UserDefaults.standard.<bool|string|integer|double|object>(forKey: "字面值")`）共 39 處，全部在 `#if DEBUG` 區塊內，包括新增的 `-openSettings`。
- `tools/unused_scan.py`：沒有新的沒有引用的程式（只剩系統入口和原本就只給測試用的 `Palette.tokens`、`LiveActivityLayout.lockScreenHeight`）。

### 畫面驗證（`tools/screens/change13/`）
| 項目 | 結果 | 說明 |
|---|---|---|
| V1 首頁，沒有訓練 | **通過** | `V1_today.png`：大標題「今天」、右上角齒輪、「下一次」卡、「本週」卡，一個畫面放得下。 |
| V2 首頁，有進行中的訓練 | **通過** | `V2_today_active.png`（UI 測試截取）：卡片是「進行中」、名稱、經過時間、「繼續」；附屬列的「訓練中」橫條；兩張卡都在附屬列上方。 |
| V3 本週卡有提醒 | **通過** | `V3_today_reminder.png`：示範資料加 `-fakeNow 2026-11-05T20:00+08:00`，最下面 warning 色的「上肢水平拉已經 15 天沒練」。 |
| V4 設定的 sheet | **通過** | `V4_settings.png`（第 1 層、右上角系統的關閉按鈕）、`V4_settings_appearance.png`（第 2 層「外觀」，主題預覽最下面是兩個部位色）。 |
| V5 歷程統計的「平衡」卡 | **通過** | `V5_balance.png`：推拉比（拉比推少，warning 色加「拉偏少」）、9 個分類的中性長條；`V5_balance_no_sets.png`：`-fakeNow 2026-11-20` 時 30 天內 0 組的分類寫 warning 色的「0 沒練」；`V5_frequency.png`：訓練頻率的部位色。 |
| V6 動作庫第 1 層 | **通過** | `V6_library.png`：每個分類只寫「N 個動作」。 |
| V7 首頁，系統「不以顏色區分」開啟 | **通過** | `V7_today_differentiate.png`：圓點裡有「下」「上」；`V7_frequency_differentiate.png`：訓練頻率圖例的色塊裡有「下」「上」「全」。用模擬器的系統設定打開（`defaults write com.apple.Accessibility DifferentiateWithoutColor`），截完關掉。 |
| V8 六個主題的首頁 | **通過** | `V8_today_<主題>.png` 六張：每個主題的強調色（開始、建議主項、今天外框、「下一次」膠囊）和兩個部位色。 |
| （每輪重跑）歷程穩定性 | **通過** | 紀錄、統計、動作庫第 1 層、分類清單（核心）各 0.5 秒連拍 5 張，遮掉最上面 200 px 比對都「全部相同」（`stability_pixel_compare.txt`）。 |

截圖逐張看過：沒有不該有的截斷或重疊，顏色都是主題 token，首頁一個畫面放得下。空資料（`E_today.png`、`E_stats.png`、`E_library.png`）：首頁「ME 下肢」「主項：—」「3 個動作」、本週 0 天 0 組、四個膠囊沒有勾勾；平衡卡 9 列都是「0 沒練」；動作庫是說明文字和 9 個「0 個動作」。

### 真實資料（R1）
做法：照 CHANGE_11 §9。乾淨安裝後用 `-importBackup tools/fixtures/real_backup.json -fakeNow <時間點 1> -dumpStats tools/fixtures/app_1.json` 啟動一次，再用時間點 2 啟動一次（不重新匯入）。兩個時間點由腳本從備份算出（備份最後一筆訓練的隔天中午、之後第一個週一 00:05），只寫在 `tools/fixtures/times.json`。`tools/verify_real_data.py` 直接讀備份 JSON、照 SPEC.md 的規則自己算一次，逐項比對；每個時間點比對 93 個數值。比對完把 App 從模擬器移除，之後的截圖都是乾淨安裝＋示範資料。真實資料和所有輸出都只在 `tools/fixtures/`（在 .gitignore 裡）。

| 項目 | 時間點 1 | 時間點 2 |
|---|---|---|
| 本週天數、組數（下肢、上肢、其他）、有氧分鐘 | 一致 | 一致 |
| 上週同期 | 一致 | 一致 |
| **本週卡的天數**（新增） | 一致 | 一致 |
| **本週卡的組數**（新增） | 一致 | 一致 |
| **本週卡每一天的部位顏色**（新增） | 一致 | 一致 |
| **本週卡的輪替膠囊**（新增） | 一致 | 一致 |
| **本週卡的提醒（分類和天數）**（新增） | 一致 | 一致 |
| **平衡卡 9 個分類的組數**（近 30 天，以前是首頁的近 30 天） | 一致 | 一致 |
| 推拉比、單邊次數、爆發次數 | 一致 | 一致 |
| 日型（上次日期、幾天前、上次主項、下次主項） | 一致 | 一致 |
| 「下一次」的日型 | 一致 | 一致 |
| 主動作的估算 1RM 與 60% 建議重量 | 一致 | 一致 |
| ~~動作庫各分類「最久沒練」~~ | 刪掉（§4） | 刪掉（§4） |

---

## 2. 2-5 有沒有遇到「先停下來」的情況：沒有
做法：拿掉 `ScreenHeader(title: "今天")` 和 `.toolbar(.hidden, for: .navigationBar)`，改成 `.navigationTitle("今天")`＋`.navigationBarTitleDisplayMode(.large)` **（CHANGE_15 §1 推翻：改成 `.toolbarTitleDisplayMode(.inlineLarge)`，大字的標題和齒輪同一列，首頁多出 52 pt。）**，齒輪是導覽列右上角的 `ToolbarItem(placement: .topBarTrailing)`（`Button("設定", systemImage: "gearshape")`，外觀交給系統）。

量法：`TodayLayoutUITests`（iPhone 17 Pro 模擬器、示範資料）量導覽列底部、兩張卡的上下緣、分頁列和附屬列的上緣。

| 狀態 | 導覽列底部 | 下一次卡 | 本週卡 | 下緣 | 空隙 |
|---|---|---|---|---|---|
| 沒有訓練 | 168 pt | 167.5–364.2 pt | 375.2–574.5 pt | 分頁列 791 pt | **+216.5 pt** |
| 有進行中的訓練（附屬列顯示） | 168 pt | 167.5–342.2 pt | 353.2–552.5 pt | 附屬列 735 pt | **+182.5 pt** |

（有訓練時「下一次」卡少一行：進行中只有名稱和經過時間，沒有主項和動作數兩行。）CHANGE_12 時系統的大標題讓近 30 天卡超出 32.5 pt；這次首頁只剩兩張卡，空出的高度足夠。`ScreenHeader` 沒有其他地方在用，一起刪掉。

---

## 3. 刪掉的程式
| 程式 | 原因 |
|---|---|
| `AppTab.settings` 和設定分頁 | §1：設定改成 sheet |
| `SettingsView` 自己的導覽路徑（`@State path`）和 `-settingsPage` 的處理 | 路徑搬到 `WorkoutCoordinator.settingsPath`；`-settingsPage` 改在 RootView 打開 sheet |
| `ScreenHeader`（`Theme/Components.swift`） | §2-5：改用系統的大標題，沒有其他地方在用 |
| `TrainingCalendar`（`Views/Today/TrainingCalendar.swift`） | §2-3：首頁的訓練日曆卡 |
| `ActivityCalendar`、`CalendarGrid`（`Logic/ActivityCalendar.swift`）和 `ActivityCalendarTests` | 只給日曆用（`TrainingCountTests` 裡用它確認週一開始的那兩行改成用本週卡的圓點） |
| `StatsSnapshot.DayStat`（`exerciseCount`、`sessionIDs`、`regions`） | 只給日曆用；改成每天的部位 `dayRegions` |
| `RecentSetsCard`（`TodayView.swift`）和 `RecentVolume`（`Logic/HomeStats.swift`，紅黃綠的門檻） | §2-3：近 30 天卡；組數搬到平衡卡，長條改中性色 |
| `CategoryTodoList`、`TodoRow`、`-todayCategory`、`WorkoutCoordinator.todayPath`、`Today` 的 `navigationDestination` | §2-3：從近 30 天卡點進去的分類待練清單；「今天」沒有第 2 層了 |
| `RegionLegend(forBars:)` 的日曆變體 | 只剩訓練頻率用圖例（一律是長條的斜紋） |
| `StatsSnapshot.neglectedDays` 和它的計算、`RealDataDebug` 和 `verify_real_data.py` 的「最久沒練」 | §4：只給動作庫分類列的「最久沒練」用 |
| `Staleness.color` 的紅綠（`done`／`danger`） | §3：改成超過 60 天 warning、其他中性 |
| `ExerciseDataTab.purposeColor`（換算表目的的紅黃綠） | §3 |
| `HistoryLine` 的 `hasMax`（有 MAX 的紀錄用 warning 色） | §3：MAX 不是警示，文字裡本來就有「(MAX)」 |

---

## 4. 每個主題調整過的顏色 token
**（CHANGE_14 §2 推翻：六個主題的 lowerBody／upperBody 都拿掉了，部位色改成共用的系統藍和系統橘。）**

| 主題 | token | 調整原因 |
|---|---|---|
| 六個主題 | `lowerBody`（新增） | §3：下肢以前直接用 accent，現在要有自己的部位色，和 accent、warning 的色相差至少 40 度 |
| 石墨藍 | `upperBody` | 原本的橘色和 warning（黃）的色相只差 18 度，會被當成警示；改成青綠色 |
| 石墨粉 | `upperBody` | 原本的天藍色和這個主題新的下肢色（淡紫）只差 50 度，兩個部位不好分；改成青綠色 |
| 石墨橙、石墨紫、石墨青、石墨銀 | `upperBody` | 沒有改（和 accent、warning、新的下肢色都夠遠） |
| 六個主題 | `textSecondary` | 沒有改：和背景、卡片、輸入框的對比度都已經超過 4.5:1（6.9、6.3、5.2，所有主題共用同一個值） |

色碼和每個主題的選擇列在 `SPEC.md` 的「9-1. 主題配色」。

---

## 5. 自行決定的事項

**§2 首頁**
1. 「下一次」卡的 DE（爆）主項（壺鈴擺盪、借力推舉、爆發划船……）只寫名稱：規格只寫了速度主項的寫法，爆發動作沒有建議重量（建立菜單顯示的是「上次 N kg」，不是建議值）。DE 速度主項完全沒有可以計算的紀錄時也只寫「主項：臥推（速度）」，不放建立菜單的「用能做得很快的重量」，讓主項一行放得下。
2. 「N 個動作」是建立菜單預設答案的動作數（不扣掉沒有候選而會略過的格子）；「跑步機 30 分鐘」的 30 是有氧的預設分鐘，抽成 `Prescription.cardioMinutes`，建立菜單的說明也用它；「做到 3RM／5RM」抽成 `Prescription.maxEffortRM`。
3. 「下一次」卡整張是一個按鈕，「開始」用主要按鈕的外觀（`PrimaryButtonLabel`），不是另一個按鈕：按鈕裡不能再放按鈕，而且規格說按按鈕或整張卡都一樣；按下時整張卡換按壓色。
4. 進行中的卡片：有日型時大字是日型、下一行是訓練名稱；沒有日型（自由選動作）時名稱當大字。經過時間用 `ElapsedTimeText`。名稱是空的時寫「訓練」。
5. 本週卡的圓點 28 pt；過去沒練的日子是 field 實心，今天之後是 field 的外框（空心）；今天的外框在圓點外面 4 pt，2 pt 粗。 **（CHANGE_14 §1：圓點換成點點日曆，今天的外框改成主要文字色。）**
6. 輪替膠囊排成兩排（ME 下肢、ME 上肢／DE 下肢、DE 上肢），和建立菜單選日型的排法一樣：一排四個時「DE 上肢・下一次」加上勾勾放不下。之後的日型文字用次要文字色。
7. 提醒的門檻直接用訓練狀態的 `TrainingStatus.isStale`（超過 14 天），天數用 `Recency.daysSince`（日曆日）。「最近一次完成組的日期」用那次訓練的開始日期，和全 App 的「上次日期」同一套（訓練跨過午夜時算開始那天）；包括封存的動作（規格寫「該分類任何動作」）。好幾個分類天數一樣多時取分類順序在前的。前面加 `exclamationmark.circle` 圖示。
8. 平衡卡的 9 列放在推拉比下面，中間一條分隔線、小標「各分類／組數」；0 組寫「0 沒練」（數字和「沒練」都是 warning 色）。
9. 「今天」沒有第 2 層了，`NavigationStack` 只留來放標題和齒輪。
10. `StatsScrollUITests` 的有氧卡測試改成先往回拖（見第 1 節），測的事情沒變。

**§1 設定**
11. 設定的 sheet 放在換主題重建的範圍外面（RootView 的最外層），在「外觀」換主題時 sheet 不會關掉；sheet 的內容自己依主題重建，導覽路徑放在 `WorkoutCoordinator`，所以會停在「外觀」。以前設定是分頁時，換主題會跳回設定的第 1 層。
12. 關閉按鈕只放在第 1 層的右上角（第 2 層左上角是系統的返回；往下拖在哪一層都能關）。關掉後再打開一律從第 1 層開始。第 1 層照舊是大標題「設定」。
13. App 裡沒有程式會切換到設定分頁（深層連結、App Intents 都只到今天、建立菜單或訓練畫面），所以「改成打開 sheet」的只有動作庫空白時的說明文字（改成「到「今天」右上角的設定 → 備份與還原」）。另外處理：sheet 開著時收到深層連結（小工具、控制項、Siri），先關掉 sheet、關完再依那時的狀態導向，因為同一時間只能呈現一個。
14. 開發用：新增 `-openSettings YES`；`-settingsPage <頁>` 改成打開 sheet 並進入該頁；`-startTab` 只剩 0～2。

**§3 顏色**
15. 部位色的選擇（`SPEC.md` 9-1）：**（CHANGE_14 §2 推翻：改成六個主題共用的系統藍、系統橘，不再要求和 accent、warning 的色相差。）**每個主題挑兩個和 accent、warning（約 42 度）都至少差 48 度的顏色，兩色之間至少 70 度、亮度相近；盡量保留原本的上肢色。測試的門檻：和 accent、warning ≥ 40 度（規格）、兩色之間 ≥ 60 度、亮度差 ≤ 0.15、彩度 ≥ 0.35。
16. 強調色只留在規格列的用途。**（CHANGE_14 §3 推翻一部分：主項進步的迷你折線、有氧的長條、體重的線和點、動作詳情的折線和點改回強調色；今天的外框改成主要文字色。）**改成中性的：主項進步的迷你折線、有氧卡的長條（選取的那一根照舊 accent，算「選取的狀態」）、體重的點和線、動作詳情的折線和點、個人紀錄的數字、「近 90 天 N 次」、備份的資料數量、完成摘要的時長和組數和勾勾圖示、健康 App 帶入的數字、角色標記、休息倒數的計時圖示和外框和進度條、說明的編號、附屬列「訓練中」的圖示、熱身組號 W、建立菜單和新增動作的「新」。留下的：主要按鈕、選取的膠囊和勾選、系統的 tint（分頁、開關、導覽列按鈕）、「設定時間」「還原」「恢復自動名稱」「＋ 記錄當天體重」這類文字按鈕、訓練中動作卡的標題（點了開說明，是連結）、建議主項和建議重量和「建議」、「下一次」、今天的外框。
17. 不用紅綠燈：主項進步的增減只留正負號（次要文字色）；換算表的目的、新紀錄、MAX 組號和 MAX 的紀錄、個人紀錄的標題都改成中性色。「N 天前」超過 60 天用 warning（很久沒練是提醒），60 天內和「未練過」用次要文字色（以前是綠、黃、紅）。
18. 封存的滑動按鈕照舊是 warning 色：那是動作按鈕（會把動作藏起來），算警示，不是狀態。
19. done 只留在完成的組（打勾、整列底色、主題預覽）和即時動態的「完成這組」：這是「完成」本身，不是好壞。
20. 訓練狀態浮窗原本沒有用到部位色；規格把它列進「改用兩個 token 的地方」，所以在「下肢 N・上肢 N」前面加上部位色的圓點，和本週卡對得上。
21. 不以顏色區分：有氧與其他是中性灰，不加字（規格只列下、上、全）；圖例的色塊放大到 14 pt 才放得下字。截圖用模擬器的系統設定打開，App 讀系統的 `accessibilityDifferentiateWithoutColor`，沒有另外加 DEBUG 參數。
22. 訓練名稱：自動名稱是輸入框的提示文字（`TextField` 的 prompt），改成主要文字色；使用者自己輸入的名稱本來就是主要文字色。點了照樣可以直接輸入。編輯過去的訓練（`SessionEditorView`）用同一個元件，一起改。
23. 小工具和即時動態是系統畫面，這次不在範圍，顏色照舊。

**§4 動作庫**
24. 規格說「如果第 2-2 節的提醒可以沿用 neglectedDays，就改成沿用」：不能沿用。neglectedDays 是「分類裡未封存、練過的動作中，最久沒練的那一個距今幾天」，提醒要的是「分類裡任何動作最近一次完成組距今幾天」，一個取最舊、一個取最新，口徑相反。所以刪掉 neglectedDays，提醒用 §2 新加的 `categoryLastDates`。

**其他**
25. R1 的兩個時間點和 CHANGE_11 一樣（備份檔沒有換，腳本算出來的時間點相同）。
26. §0 的第一次 commit 不小心連同已經 `git rm` 的四個檔案一起提交（那個 commit 單獨不能建置）；還沒推上去，重做了 §0 和 §2 兩個 commit，讓 §0 只有原文。
27. 開發用的 `-theme.id` 截圖注意：啟動時的舊主題遷移（`migrateLegacySettings`）會把讀到的主題寫回設定，所以用 `-theme.id` 截過之後要再用 `-theme.id graphiteOrange` 啟動一次才會回到預設。只影響開發用的截圖流程。

---

## 6. 未解決的事項
- **沒有觸發規則 3**（沒有任何條件連續修 3 次還過不了）。
- 沒有「先停下來」的情況（第 2 節）。
- 觀察到：§4 的全部測試裡 `StatsScrollUITests.testDragFromFrequencyChartScrolls` 有一次沒過（拖曳後畫面沒動），單獨重跑兩次都通過，最後一輪全部測試也通過；和 §4 的改動無關（§3 時同一個測試通過），是模擬器偶爾漏掉手勢。
- 觀察到、照規格做：空資料時平衡卡 9 列都是 warning 色的「0 沒練」（`E_stats.png`），剛裝好還沒有紀錄時會一整排黃字。要不要在完全沒有紀錄時改成一行說明，需要你決定。 **（CHANGE_14 §5：完全沒有紀錄時改成「還沒有紀錄」。）**
- CHANGE_11 留下的兩個 DEBUG 小問題照舊（`-emptyData` 之後再 `-demoData` 沒有輪替順序、`-scrollToBottom 分類` 最後一列在分頁列後面），只影響開發用的參數。

---

## 7. 實機確認清單
1. **齒輪按鈕的位置和手感**：「今天」右上角的齒輪好不好按、單手拇指搆不搆得到；點了用 sheet 打開設定，右上角的關閉、往下拖關閉；在「外觀」換主題時 sheet 不會關掉、還停在「外觀」；關掉後再打開是第 1 層。
2. **首頁兩張卡的感覺**：一個畫面放得下（不用捲）；「下一次」卡的主項和建議重量（DE 日看看建議重量和建立菜單裡的一樣）、「開始」和點卡片其他地方都進建立菜單；訓練中時卡片變成「進行中」和經過時間、「繼續」打開訓練畫面；本週卡的「N 天・N 組」和點開的訓練狀態一樣；圓點的顏色和你這週實際練的部位對得上；輪替膠囊的勾勾；兩週沒練某個分類時的提醒。
3. **顏色在實際光線下是否好分辨**：健身房的燈光下，下肢和上肢兩個部位色分不分得出來、和強調色（今天的外框、「下一次」膠囊）和 warning 的黃（提醒）分不分得出來；如果換過主題，六個主題各看一下。也可以打開「設定 › 輔助使用 › 顯示與文字大小 › 不以顏色區分」看圓點裡的字。
4. **顏色的意思**：圖表和數字改成中性色之後（主項進步、體重、有氧、個人紀錄、換算表），看起來會不會太平；「拉偏少」「0 沒練」、超過 60 天沒練的黃字是不是剛好提醒到該注意的地方。
5. **訓練畫面的名稱**：自動名稱改成白色粗體之後，還看得出可以點下去改名嗎。
6. **歷程統計的平衡卡**：9 個分類的長條（從首頁搬過來）讀起來順不順。
7. **動作庫第 1 層**：只剩「N 個動作」，還需不需要其他資訊。
8. **小工具或控制中心在設定開著時打開 App**：會先關掉設定再進建立菜單或訓練畫面。

---

## 8. 截圖索引（`tools/screens/change13/`）
| 檔名 | 內容 | 標準 |
|---|---|---|
| `V1_today.png` | 首頁，沒有訓練：大標題、齒輪、「下一次」卡、「本週」卡 | V1 |
| `V2_today_active.png` | 首頁，有進行中的訓練：「進行中」卡片和附屬列（UI 測試截取） | V2 |
| `V3_today_reminder.png` | `-fakeNow 2026-11-05`：本週卡最下面的提醒 | V3 |
| `V4_settings.png` | 設定的 sheet 第 1 層，右上角系統的關閉按鈕 | V4 |
| `V4_settings_appearance.png` | 設定的第 2 層「外觀」：主題預覽有兩個部位色 | V4、§3 |
| `V5_balance.png` | 歷程統計的平衡卡：「拉偏少」、9 個分類的中性長條 | V5 |
| `V5_balance_no_sets.png` | `-fakeNow 2026-11-20`：30 天內 0 組的分類寫「0 沒練」 | V5、§3 |
| `V5_frequency.png` | 訓練頻率的部位色長條和圖例 | §3 |
| `S5_training_status.png` | 訓練狀態浮窗：本週（和本週卡同一份數字）、部位色的圓點 | S5、§3 |
| `V6_library.png` | 動作庫第 1 層：每個分類只寫「N 個動作」 | V6 |
| `V7_today_differentiate.png` | 系統「不以顏色區分」開啟：圓點裡的「下」「上」 | V7 |
| `V7_frequency_differentiate.png` | 同上，訓練頻率圖例的「下」「上」「全」 | V7 |
| `V8_today_<graphiteOrange｜graphiteBlue｜graphitePurple｜graphitePink｜graphiteCyan｜graphiteSilver>.png` | 六個主題的首頁 | V8 |
| `stability_<紀錄 records｜統計 stats｜動作庫 library｜分類 category>_1～5.png` | 捲到底部後每 0.5 秒連拍 | 歷程穩定性 |
| `stability_pixel_compare.txt` | 四組都「全部相同」 | 歷程穩定性 |
| `E_today.png`、`E_stats.png`、`E_library.png` | 空資料的首頁、統計、動作庫 | 空狀態 |

---

## 9. commit 列表
```
ce82203 CHANGE_13 §4: library category rows show only the exercise count
bdfd6cc CHANGE_13 §3: one meaning per color; body colors per theme
43d04bc CHANGE_13 §1: settings open from the gear on Today; three tabs
f95faa9 CHANGE_13 §2: Today is two cards — next workout and this week
8bce15c CHANGE_13 §0: save the prompt
```
加上最後一個文件 commit（這份報告、SPEC.md、STATUS.md、舊報告的註記、截圖）。
