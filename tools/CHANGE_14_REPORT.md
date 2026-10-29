# CHANGE_14 點點日曆回到本週卡、部位色改成系統藍橘、圖表上色、訓練摘要改成推入頁面：最終報告

- 日期：2026-10-29
- 範圍：§0 存原文；§2 部位色改成六個主題共用的系統藍（下肢）和系統橘（上肢），warning 色的地方都加上圖示或文字；§1 本週卡的 7 個圓點換成點點日曆（最右邊一欄是本週）；§3 單一數列的圖表用強調色、長條選取時其他的變淡；§4 訓練摘要從浮窗改成推入的頁面、訓練狀態的輪替列不能點；§5 平衡卡完全沒有紀錄時寫「還沒有紀錄」。實作順序是 §2 → §1 → §3 → §4 → §5（日曆要用 §2 的部位色），每一節各自 commit，都是建置成功、全部測試通過後才 commit。CLAUDE.md 的執行規則 1～7 照常適用（這次沒有資料遷移，資料模型和備份格式都沒有改）。
- 結果摘要：**五節都完成，沒有遇到「先停下來」的情況**。日曆用 14 pt 的格子（20 週）兩種狀態都放得下（沒有訓練時本週卡底部離分頁列 117.5 pt，有附屬列時離附屬列 83.5 pt），不用縮到 12 pt。R1 真實資料比對兩個時間點全部一致。
- 驗證環境：Xcode 27.1（`/Applications/Xcode.app`），iPhone 17 Pro 模擬器（iOS 26.5），測試一律 `-parallel-testing-enabled NO`。最後的截圖在乾淨安裝後用 seed＋示範訓練（`-demoData`），空資料（`-emptyData`）放在最後。真實資料只在 R1 比對時匯入，比對完就把 App 從模擬器移除，之後才截圖。
- 文件：`CLAUDE.md`（顏色的規則：強調色、部位色、warning 一定要有圖示或文字；設計原則加上訓練摘要是推入頁面的例外；共用做法加上 `ChartEmphasis`）、`SPEC.md`（開頭摘要、資訊架構、點擊提示、圖表的顏色、今天的本週卡、訓練狀態、統計快取、開始訓練、歷程的訓練摘要頁、動作詳情、動作庫、設定、主題配色、深層連結、統計、開發用參數、已移除）、`tools/STATUS.md`、`tools/changes/README.md`（加上 CHANGE_14）已更新；`tools/CHANGE_13_REPORT.md`（圓點和部位色的測試、第 4 節每個主題的部位色、自行決定 5、15、16、未解決裡平衡卡的空資料）、`tools/CHANGE_10_REPORT.md`（自行決定 30 輪替列打開摘要）、`tools/CHANGE_07_REPORT.md`（自行決定 24 浮窗關掉才刪）加了粗體註記。

---

## 1. 收斂標準的結果

### 建置與測試
| 項目 | 結果 | 驗證方式 |
|---|---|---|
| G1 Debug、Release 0 error 0 warning | **通過** | 最後的程式（`3852031`）clean build 三種：Debug（含單元測試和 UI 測試 target，`build-for-testing`）、Release 模擬器（`generic/platform=iOS Simulator`）、Release 實機（`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO`），`grep -c 'error:'`、`grep -c 'warning:'` 都是 0。 |
| G2 全部測試通過 | **通過** | 最後的程式乾淨安裝後跑全部測試：**281 個全部通過**、0 失敗。單元測試 251（38 檔）＋UI 測試 30（12 檔＋共用）。CHANGE_13 結束時 269 個：單元新增 9（`TodayCardsTests` 日曆 6 個取代圓點 2 個；`ThemeTests` 部位色 2 個取代 1 個；`ChartEmphasisTests` 2；`BalanceCardTests` 2）；UI 新增 3（`SummaryPageUITests`）。 |

G2 要求的新測試：

| 規格要求 | 測試 | 結果 |
|---|---|---|
| 日曆：欄數依寬度計算且至少 12 週 | `TodayCardsTests.calendarColumnsFollowTheWidthAndAreAtLeastTwelveWeeks`：卡片裡 338 pt 時 14 pt 的格子 20 週、12 pt 22 週；337／336 pt 的邊界；格子限制在 12～14；200 pt 時縮小格子塞滿 12 週、150 pt 時 12 週 12 pt；7 列的高度 | 通過 |
| 日曆：最右邊一欄是本週（週一到週日） | `lastColumnIsThisWeekMondayToSunday`：20 欄，最後一欄 10/26（週一）到 11/1（週日）（地區設定的一週從週日開始也一樣）；每一欄是連續的一週、從週一開始；第一欄是 19 週前 | 通過 |
| 日曆：今天的外框、本週之後的日子只有外框 | `todayIsMarkedAndTheRestOfThisWeekIsOutlined`：只有今天是「今天」；本週今天之後的 4 天是「之後」而且即使有資料也不上色；今天有練時照部位上色；前面的週沒有之後的日子；週一 0 點、週日晚上、下一個週一的邊界 | 通過 |
| 日曆：月份標在每個月第一個週一那一欄 | `monthsAreLabeledOnTheFirstMondayColumn`：20 週裡標在 7/6、8/3、9/7、10/5（「7月」…「10月」），6/15 那欄不標；`monthLabel` 的 1～7 號規則 | 通過 |
| 日曆：跨月和跨年 | `calendarCrossesMonthsAndTheYear`：2027/1/6 時最後一欄 2027/1/4 標「1月」；12/28～1/3 同一欄、不標月份、跨年的部位對得上；11/30 那欄不標、12/7 標「12月」 | 通過 |
| 日曆每一格的部位和 dayRegions 一致 | `cellsMatchTheSnapshotDayRegions`：每一格都等於快照的 `dayRegions`；同一天下肢、上肢分兩次練是全身；只有有氧是有氧與其他（中性灰）；有氧不影響有重訓的日子；沒打勾的那天沒有顏色；第一欄（13 週前）也有。SwiftData 版本的「沒打勾不算」在 `TrainingRegionTests` | 通過 |
| 部位色：六個主題相同 | `ThemeTests.bodyColorsAreTheSameSystemColorsInEveryTheme`：`BodyPart` 是 `systemBlue`、`systemOrange`；六個主題的 token 都沒有 lowerBody／upperBody；`Theme.lowerBody`／`upperBody` 解析出來就是這兩個系統色；日曆和長條的 swatch 不讀主題；「增加對比」時換成加強的版本（不是寫死的色碼） | 通過 |
| 部位色：色相差至少 60 度、和卡片背景的對比度至少 3:1 | `bodyColorsAreDistinctAndVisibleOnCards`：一般和增加對比都量（深色）。色相差約 174 度；對比度（卡片 #1B1C1F）：藍 4.67:1、橘 8.29:1，增加對比時 6.02:1、9.55:1 | 通過 |
| 拿掉「部位色和強調色、warning 色差 40 度」 | `bodyColorsAreDistinctFromAccentAndWarning` 刪掉 | 完成 |
| 圖表：單一數列用強調色 | `ChartEmphasisTests.singleSeriesChartsUseTheAccent`：數列的顏色解析出來是目前主題的 accent、不透明；S4 的 grep 確認四張圖都用它 | 通過 |
| 圖表：長條圖選取時其他長條變淡，取消選取後恢復 | `barsDimTheOthersWhileOneIsSelected`：沒有選取時都是 accent 100%；選取時選到的那一根 100%、其他 40%；取消後和沒有選取一樣；折線圖選到的點放大。UI 測試 `ChartSelectionUITests.testTapOnCardioChartSelectsAWeek`：點一根有分鐘數的長條（截圖 `V4_cardio_selected`），2 秒後選取消失（`V4_cardio_restored`） | 通過 |
| UI：歷程「紀錄」點一筆 → 推入摘要頁 → 返回 | `SummaryPageUITests.testRecordPushesTheSummaryAndGoesBack`：導覽列「訓練摘要」在畫面最上面（全高）、有返回和 ⋯；系統的返回回到歷程；再點一次，從左邊緣往右滑也回到歷程；捲到最底截圖 | 通過 |
| UI：⋯ 的「編輯」打開編輯的 sheet；刪除後回到上一頁 | `testEditOpensTheEditorAndDeleteGoesBack`：用 `-demoDeletable` 加的「刪除測試」：⋯ →「編輯」打開「編輯訓練」，「完成」回到摘要頁；⋯ →「刪除」出現置中的 alert（有「取消」），確認後回到歷程，那一列不見了 | 通過 |
| UI：動作詳情「歷史」點一筆 → 推入同一個摘要頁 | `testExerciseHistoryPushesTheSameSummaryPage`：動作庫 → 臥推 → 歷史，點一行推入「訓練摘要」，返回回到「臥推」 | 通過 |
| UI：訓練狀態浮窗的輪替列點了沒有反應 | `TrainingStatusUITests.testWeekCardOpensTrainingStatus`：輪替列不是按鈕（有「天前」的按鈕 0 個）；點了之後訓練狀態還開著、沒有摘要頁也沒有 ⋯ | 通過 |
| 平衡卡：完全沒有紀錄時「還沒有紀錄」；有紀錄但 30 天內 0 組時「0 沒練」 | `BalanceCardTests.noRecordsAtAll`（空資料、只有沒打勾的組）；`recordsOlderThanThirtyDaysShowZeroNotTrained`（紀錄都在 30 天前時 9 列都是「0 沒練」；30 天內有練的分類寫組數） | 通過 |
| UI：首頁在沒有訓練、有進行中的訓練時都一個畫面放得下 | `TodayLayoutUITests` 兩個測試：兩張卡都在導覽列下面、本週卡整張在分頁列（或附屬列）上方，量到的數字存成附件 | 通過（117.5 pt、83.5 pt，見第 2 節） |

其他改寫的測試：
- `TrainingCountTests.weeksStartOnMonday`：以前用本週卡的圓點確認週一開始，改成日曆的最後一欄。
- `WorkoutLauncherTests.backfillIsAnEndedSessionWithoutRestOrConflict`：補登以前打開摘要浮窗，改成確認切到歷程、路徑是那次訓練的摘要頁、直接進入編輯。
- `SessionTimeEditTests`：時間文字的函式跟著搬到 `WorkoutSummaryPage.timeText`。
- `TrainingRegionTests`：註解的「圓點」改成「日曆」。

### 程式碼檢查
| 項目 | 結果 | 檢查方式 |
|---|---|---|
| S1 六個主題沒有各自的 lowerBody／upperBody，部位色只有一份共用的定義，而且是系統色 | **通過** | `Palette` 沒有 `lowerBody`／`upperBody`（`grep` `palette.lowerBody`、`p.lowerBody`、`lowerBody:` 0 筆），`AppTheme.palette` 只換 accent、onAccent。共用的定義是 `Shared/Theme.swift` 的 `BodyPart`（`.systemBlue`、`.systemOrange`），`Theme.lowerBody`／`upperBody`、`DayRegion.swatch`、全身的斜紋、主題預覽都讀它。測試同上。 |
| S2 訓練摘要沒有任何地方用 sheet 呈現，只剩推入的頁面 | **通過** | `grep` `WorkoutSummarySheet`、`summarySession`、`origin: .summary`：0 筆。`WorkoutSummaryPage` 只出現在歷程和動作庫的 `navigationDestination(for: WorkoutSession.self)`；`.sheet`／`.fullScreenCover` 裡沒有摘要（摘要頁自己的 sheet 是記錄體重和全螢幕的編輯）。完成訓練後的 `WorkoutSummaryView` 是訓練流程的完成畫面，照規格維持原樣。 |
| S3 本週卡原本 7 個圓點的程式已刪除 | **通過** | `grep` `WeekDot`、`weekdayLabels`、`WeekCard.days(`：0 筆。 |
| S4 第 3 節列出的圖表都使用強調色的 token | **通過** | `ChartEmphasis.series`（`Theme.accent`）用在：主項進步的 `Sparkline`、`CardioCard` 的 `BarMark`（`ChartEmphasis.bar`）、`BodyWeightCard` 的 `LineMark`／`PointMark`（含 7 日平均和選到的點）、`TrendChartCard` 的 `LineMark` 和 `chartForegroundStyleScale`（一般、MAX）。訓練頻率照舊是 `region.barFill`。 |
| S5 每一個用到 warning 色的地方都有圖示或文字 | **通過** | 逐一列在第 3 節。文字的提醒都走 `Text.warning`（前面一定加 `exclamationmark.circle`）；`grep Theme.warning` 剩下的 8 處都是 Label（有圖示）、`Text.warning` 本身、平衡卡（有「拉偏少」「沒練」文字）和封存的滑動按鈕（按鈕文字「封存」）。 |
| S6 新增的 DEBUG 參數都在 `#if DEBUG` 裡 | **通過** | 腳本列出所有 `UserDefaults.standard`／`defaults` 的 `.bool|string|integer|double|object(forKey: "字面值")`：46 處（含 DemoData 用參數傳入的 `defaults`），全部在 `#if DEBUG` 區塊內，包括新增的 `-demoDeletable`（`DemoData.swift` 整個檔在 `#if DEBUG` 裡，RootView 呼叫的地方也是）。 |

另外：`tools/unused_scan.py --tests` 沒有新的沒有引用的程式（只剩系統入口和原本就只給測試用的 `Palette.tokens`、`LiveActivityLayout.lockScreenHeight`）。

### 畫面驗證（`tools/screens/change14/`）
| 項目 | 結果 | 說明 |
|---|---|---|
| V1 首頁，沒有訓練：本週卡的點點日曆 | **通過** | `V1_today.png`：20 週的日曆，最右邊一欄是本週；7 月～10 月標在第一個週一；今天（週四）外面一圈白框，之後的 3 天只有外框；下面是圖例、輪替膠囊。 |
| V2 首頁，有進行中的訓練 | **通過** | `V2_today_active.png`（UI 測試截取）：「進行中」卡片和日曆都在附屬列上方（空隙 83.5 pt）。 |
| V3 六個主題的首頁 | **通過** | `V3_today_<主題>.png` 六張：日曆和圖例的藍、橘六張都一樣；開始按鈕、建議主項、「下一次」膠囊是各自的強調色。 |
| V4 歷程統計的圖表 | **通過** | `V4_stats_mainlifts_weight.png`（主項進步的迷你折線、體重的線和點都是強調色）、`V4_stats_cardio_frequency.png`（有氧長條強調色、訓練頻率部位色）、`V4_cardio_selected.png`（選到 8/17 那週，那一根強調色、其他變淡）、`V4_cardio_restored.png`（2 秒後恢復）、`V4_stats_balance.png`。 |
| V5 動作詳情的折線圖選取 | **通過** | `V5_detail_chart_peek.png`（UI 測試截取）：選到的菱形放大、浮出「7/24・58.4 kg」；`V5_detail.png` 沒有選取時。 |
| V6 訓練摘要的推入頁面 | **通過** | `V6_summary_page_top.png`、`V6_summary_page_bottom.png`（UI 測試截取）：系統的返回、標題「訓練摘要」、⋯；名稱、日期、時間、體重、5 個動作和備註都完整。示範訓練的內容一個畫面放得下，所以捲到最底和最上面一樣；`summary_page_from_detail.png` 是從動作詳情推入的同一頁。 |
| V7 空資料的平衡卡 | **通過** | `V7_balance_empty.png`：平衡卡只有一行「還沒有紀錄」。 |
| V8 系統「不以顏色區分」開啟時的首頁 | **通過** | `V8_today_differentiate.png`：格子裡不放字，圖例的色塊放大並加上「下」「上」「全」；`V8_frequency_differentiate.png`：訓練頻率圖例。用模擬器的系統設定打開（`defaults write com.apple.Accessibility DifferentiateWithoutColor`），截完關掉。 |
| （每輪重跑）歷程穩定性 | **通過** | 紀錄、統計、動作庫第 1 層、分類清單（核心）各 0.5 秒連拍 5 張，遮掉最上面 200 px 比對都「全部相同」（`stability_pixel_compare.txt`）。 |

截圖逐張看過：沒有不該有的截斷或重疊，顏色都是主題 token 或共用的系統部位色，首頁一個畫面放得下。空資料（`E_today.png`、`E_library.png`）：首頁「ME 下肢」「主項：—」「3 個動作」、本週 0 天 0 組、日曆全是沒練的格子（今天有白框）、四個膠囊沒有勾勾；動作庫是說明文字和 9 個「0 個動作」。

### 真實資料（R1）
做法：照 CHANGE_11 §9。乾淨安裝後用 `-importBackup tools/fixtures/real_backup.json -fakeNow <時間點 1> -dumpStats tools/fixtures/app_1.json` 啟動一次，再用時間點 2 啟動一次（不重新匯入）。兩個時間點由腳本從備份算出（備份最後一筆訓練的隔天中午、之後第一個週一 00:05），只寫在 `tools/fixtures/times.json`。`tools/verify_real_data.py` 直接讀備份 JSON、照 SPEC.md 的規則自己算一次，逐項比對；這次加上日曆的週數（依螢幕寬度 402 pt 自己算）和日曆顯示的每一天的部位（20 週 × 7 天），每個時間點比對 227 個數值。比對完把 App 從模擬器移除，之後的截圖都是乾淨安裝＋示範資料。真實資料和所有輸出都只在 `tools/fixtures/`（在 .gitignore 裡）。

| 項目 | 時間點 1 | 時間點 2 |
|---|---|---|
| 本週天數、組數（下肢、上肢、其他）、有氧分鐘 | 一致 | 一致 |
| 上週同期 | 一致 | 一致 |
| 本週卡的天數 | 一致 | 一致 |
| 本週卡的組數 | 一致 | 一致 |
| **日曆的週數**（新增） | 一致 | 一致 |
| **日曆顯示的每一天的部位**（新增，取代 CHANGE_13 的 7 個圓點） | 一致 | 一致 |
| 本週卡的輪替膠囊 | 一致 | 一致 |
| 本週卡的提醒（分類和天數） | 一致 | 一致 |
| 平衡卡 9 個分類的組數（近 30 天） | 一致 | 一致 |
| 推拉比、單邊次數、爆發次數 | 一致 | 一致 |
| 日型（上次日期、幾天前、上次主項、下次主項） | 一致 | 一致 |
| 「下一次」的日型 | 一致 | 一致 |
| 主動作的估算 1RM 與 60% 建議重量 | 一致 | 一致 |

---

## 2. 第 1 節有沒有遇到「先停下來」的情況：沒有
日曆用 14 pt 的格子（範圍的上限）、間距 3 pt，iPhone 17 Pro 的卡片裡（338 pt）放得下 20 週。月份一列 18 pt、7 列格子 116 pt、圖例一列，本週卡比 CHANGE_13 高約 99 pt。

量法：`TodayLayoutUITests`（iPhone 17 Pro 模擬器、示範資料）量導覽列底部、兩張卡的上下緣、分頁列和附屬列的上緣。

| 狀態 | 導覽列底部 | 下一次卡 | 本週卡 | 下緣 | 空隙 |
|---|---|---|---|---|---|
| 沒有訓練 | 168 pt | 167.5–364.2 pt | 375.2–673.5 pt | 分頁列 791 pt | **+117.5 pt** |
| 有進行中的訓練（附屬列顯示） | 168 pt | 167.5–342.2 pt | 353.2–651.5 pt | 附屬列 735 pt | **+83.5 pt** |

兩種狀態都放得下，不需要縮到 12 pt。

---

## 3. 第 2 節：用到 warning 色的地方和搭配的圖示或文字
| 地方 | 什麼時候是 warning 色 | 搭配的圖示或文字 |
|---|---|---|
| 「今天」本週卡的提醒 | 分類超過 14 天沒練 | `exclamationmark.circle` ＋「下肢拉已經 18 天沒練」 |
| 訓練狀態浮窗的「N 天前（10/15）」 | 該日型超過 14 天 | `exclamationmark.circle`（**這次新增**，`Text.warning`）＋天數 |
| 動作庫的動作列「下肢推・75 天前」 | 超過 60 天沒練 | `exclamationmark.circle`（**這次新增**，`Staleness.text`），分類名稱維持次要文字色 |
| 建立菜單和換動作的候選「75 天前」（`CandidateRow`） | 超過 60 天沒練 | `exclamationmark.circle`（**這次新增**） |
| 新增動作的列「75 天前」 | 超過 60 天沒練 | `exclamationmark.circle`（**這次新增**） |
| 動作詳情頁首「上次 75 天前」 | 超過 60 天沒練 | `exclamationmark.circle`（**這次新增**） |
| 歷程統計的平衡卡「推：拉 45：36」 | 拉比推少 | 文字「拉偏少」 |
| 平衡卡 9 個分類 | 30 天內 0 組 | 文字「0 沒練」 |
| 設定 › 關於「簽署到期 …・還有 1 天」 | 剩一天以內 | `exclamationmark.circle`（**這次新增**）＋「還有 1 天」／「今天到期」 |
| 補登、編輯訓練「結束時間必須晚於開始時間」 | 結束早於開始 | 文字本身，**這次也加上** `exclamationmark.circle` |
| 記錄體重「這天已經有 69.3 kg，儲存會覆蓋」 | 同一天已有體重 | 文字本身，**這次也加上** `exclamationmark.circle` |
| 建立菜單和訓練中卡片的安全提示（ME「設好安全槓」、DE（爆）「速度掉了就停」） | 一直是 | `exclamationmark.triangle.fill` 的 Label ＋文字 |
| 動作庫列的滑動按鈕「封存」 | 一直是（動作按鈕） | 按鈕文字「封存」 |

以前只靠顏色的是前 6 項的「N 天前」和簽署到期（數字本身看不出是不是提醒）；文字本身就是提醒的兩項也一起改用 `Text.warning`，全 App 的文字提醒都同一個樣子。

---

## 4. 第 4 節：會打開訓練摘要的入口
| 入口 | 做法 |
|---|---|
| 歷程「紀錄」的列 | 在歷程的 NavigationStack 推入摘要頁（`coordinator.historyPath.append`） |
| 動作詳情「歷史」分頁的列 | `NavigationLink(value: session)`，推入動作詳情所在的 NavigationStack：從歷程統計的主項進步進去是歷程，從動作庫進去是動作庫（兩邊都註冊了 `navigationDestination(for: WorkoutSession.self)`） |
| 動作詳情「數據」的個人紀錄（每一項的那次訓練） | 同上（規格的「所有入口都用這個推入的頁面」） |
| 補登訓練（歷程 ⋯ → 補登 → 照建議建立菜單或自由選動作） | 建立已結束的訓練後 `WorkoutCoordinator.showSummary`：切到歷程、路徑換成只有這次的摘要頁、直接打開編輯（自由選動作時接著打開新增動作） |
| 開發用 `-openSummary latest｜edit` | 同補登：切到歷程推入（`edit` 直接進入編輯） |
| ~~訓練狀態浮窗的輪替列~~ | 拿掉：只顯示資訊，不能點 |

不會打開某一次訓練摘要的：深層連結（`liftlog://new`、`workout`、`today`）、小工具、控制項、App Shortcut、即時動態。完成訓練後的完成畫面（`WorkoutSummaryView`）是訓練流程的一部分，照舊是全螢幕。

---

## 5. 刪掉的程式
| 程式 | 原因 |
|---|---|
| `WeekCard.days(regions:now:calendar:)`、`WeekCard.weekdayLabels`、原本的 `WeekCard.Day`（7 個圓點的一天） | §1：換成點點日曆的 `WeekCard.weeks`、`Week`、`Day`（日曆的一格） |
| `WeekDot`（`TodayView.swift`） | §1：7 個圓點的畫面 |
| `TodayCardsTests.dotsAreColoredByRegionAndTodayIsMarked`、`mondayAndSundayBoundaries` | §1：換成日曆的 6 個測試 |
| `Palette.lowerBody`／`upperBody`、六個主題的部位色碼、`tokens` 裡的兩項 | §2：部位色改成共用的 `BodyPart` |
| `DayRegion.swatch(_ palette:)`（改成不讀主題的 `swatch`）、`DayRegion.stripes` | §2：斜紋搬進依環境解析顏色的 `RegionStripes` |
| `ThemeTests.bodyColorsAreDistinctFromAccentAndWarning` | §2：規格要求拿掉 |
| `Staleness.color` | §2：換成加上圖示的 `Staleness.text` |
| `WorkoutSummarySheet`（改寫成 `WorkoutSummaryPage`）、`WorkoutCoordinator.summarySession`、RootView 的摘要 sheet、深層連結 today 清掉摘要的那一行 | §4：摘要改成推入的頁面 |
| `WorkoutLauncher.Origin.summary` 和它的分支 | §4：頁面不是 sheet，「再做一次」用 root 的確認 |
| `TrainingStatusSheet.openSummary` 和只給它用的 environment（context、coordinator、launcher、dismiss） | §4：輪替列不能點 |
| `ExerciseDetailView.open(_:)`、`HistoryCard.onOpen`、`ExerciseDataTab.onOpenSession`、`HistoryView` 自己的 `path` | §4：改用 `NavigationLink(value:)` 和 coordinator 的歷程路徑 |
| `BalanceCard` 直接讀 `recentSets` 的參數 | §5：換成 `BalanceCardContent` |

---

## 6. 自行決定的事項

**順序**
1. 實作順序 §2 → §1 → §3 → §4 → §5：日曆的格子要用 §2 的部位色，先改部位色。每一節各自 commit。

**§2 部位色和 warning**
2. 共用的定義是 `Shared/Theme.swift` 的 `BodyPart`（`.lower` → `UIColor.systemBlue`、`.upper` → `UIColor.systemOrange`）。`Theme.lowerBody`／`upperBody` 保留這兩個名字但改成讀 `BodyPart`，所以用到部位色的畫面（日曆、圖例、訓練狀態的圓點、訓練頻率、主題預覽）都是同一份。
3. 全身的斜紋是一張圖案（`ImagePaint`），系統色不會自己跟著環境變：改成自訂的 `ShapeStyle`（`RegionStripes`），用畫面的環境（深色、增加對比）解析兩個系統色後再畫。可能在背景的繪製執行緒解析，所以是 `nonisolated`。
4. 測試的對比度和色相用深色（App 固定深色）量，一般和「增加對比」兩種都量；背景用卡片 #1B1C1F（六個主題相同）。
5. warning：新增 `Text.warning(_:when:normal:)`，warning 時前面一定加 `exclamationmark.circle`，不是 warning 時用指定的中性色、不加圖示；「N 天前」用 `Staleness.text`。只靠顏色的地方（「N 天前」、簽署到期）都改用它；文字本身就是提醒的「結束時間必須晚於開始時間」「這天已經有…」也改用它，讓全 App 的文字提醒都一樣。平衡卡（「拉偏少」「0 沒練」）、安全提示（三角形圖示）、封存的滑動按鈕（按鈕文字）本來就有文字或圖示，不動。
6. 動作庫的列「下肢推・75 天前」：圖示加在天數前面，分類名稱維持次要文字色。

**§1 點點日曆**
7. 格子用 14 pt（範圍的上限）：兩種狀態都放得下（117.5 pt、83.5 pt），不需要縮。欄數是 `floor((寬度 + 3) ÷ 17)`，至少 12；放不下 12 週時才把格子縮小（最小 12 pt）塞滿 12 週。iPhone 17 Pro 是 20 週，日曆不另外拉寬（右邊剩 1 pt）。
8. 月份寫「11月」，跨年的一月一樣寫「1月」（不加年份，規格只寫月份）。最右邊一欄（本週）是那個月第一個週一時，字靠右對齊，不超出日曆；其他欄靠左。每個月只有一個第一個週一，相鄰的標籤至少隔 4 欄，不會疊在一起。
9. 今天：格子外面 2.5 pt、1.5 pt 粗的主要文字色圓角框（只佔格子間距的一部分，不蓋到隔壁的格子）。本週之後：field 色 1.5 pt 的外框，不填色。沒練的日子 field 實心。
10. 圖例用 `RegionLegend(style: .cells)`：全身的色塊沿對角線兩色（和格子一樣）；訓練頻率的圖例照舊是斜紋（和長條一樣）。圖例一直顯示，空資料也有。
11. 日曆整塊是本週卡按鈕裡的一個無障礙元素「近 20 週的訓練日曆」，格子不能點、沒有自己的手勢。
12. 「範圍延伸到日曆顯示的所有週」：快照的 `dayRegions` 本來就是全部紀錄的每一天，所以沒有改計算，日曆直接讀它。
13. R1：`-dumpStats` 加上日曆的週數（依模擬器的螢幕寬度扣掉兩層 16 pt 邊距）和每一天的部位；比對腳本用螢幕寬度 402 pt 自己算週數和日期。

**§3 圖表**
14. 體重：每天的點（強調色 60%）和細線（35%）淡一點，7 日平均是實色的粗線（2 pt），都算同一個數列的強調色；右上角圖例的線是強調色、字是次要文字色。選到的那一天畫一個放大的實色點。
15. 折線圖選到的點：一般的點 36 → 130（MAX 菱形本來就大一點，放大 1.6 倍）。動作詳情的線是強調色 60%、點是實色。
16. 有氧長條：沒選到的變成 40% 不透明度，切換時用全 App 的 `.tap` 動畫。
17. 格線、座標軸、軸上的文字用系統預設的中性灰（CHANGE_13 也是預設），沒有另外指定。

**§4 訓練摘要頁**
18. 導航的值直接用 `WorkoutSession`（SwiftData 的模型本來就是 Hashable），歷程和動作庫的 NavigationStack 都註冊 `navigationDestination(for: WorkoutSession.self)`；動作詳情用 `NavigationLink(value:)`，在哪個 stack 就推到哪個。
19. 打破 CLAUDE.md「第 3 層不再 push」：規格要求在各自的 NavigationStack 推入，所以動作庫 → 分類 → 動作詳情 → 摘要是第 4 層。摘要頁本身不再往下推（動作卡不能點）。CLAUDE.md 的設計原則加了這個例外。
20. 頁面標題「訓練摘要」（inline），內容的邊距 16 pt（和動作詳情一樣，以前浮窗是 20）。
21. 補登和 `-openSummary` 這類從別的地方打開的：切到歷程，路徑換成只有摘要頁（`NavigationPath([session])`），返回就是歷程的第 1 層。歷程的導覽路徑因此搬到 `WorkoutCoordinator.historyPath`。
22. 刪除：確認後先返回上一頁，頁面 `onDisappear` 時才刪，畫面不會再讀到已刪除的資料（以前是浮窗關掉才刪，同樣的原因）。
23. 「再做一次」：頁面不是 sheet，開始衝突的確認改由 RootView 呈現，開始後直接展開訓練畫面；收合訓練畫面後回到原本的摘要頁（沒有自動返回）。
24. 個人紀錄的列也推入摘要頁：規格列的是「紀錄」和「歷史」，但也要求「所有入口都用這個推入的頁面」。
25. 刪除的 UI 測試不刪示範資料：新增 `-demoDeletable YES`，加一筆剛結束的有氧訓練「刪除測試」（已經有就不加），測試把它刪掉。

**§5 平衡卡**
26. 「完全沒有任何完成組的紀錄」用快照判斷：已結束的訓練裡有沒有任何完成的組（`StatsSnapshot.hasCompletedSets`）。只有沒打勾的組也算沒有紀錄。卡片標題「平衡・近 30 天」保留，下面一行「還沒有紀錄」。

**其他**
27. §1 的第一次全部測試有 1 個單元測試沒過（`cellsMatchTheSnapshotDayRegions`）：測試自己造了一個「沒打勾」的組放進 `PlanHistory.Item`，但 App 從 SwiftData 轉換時只帶完成的組，那種資料不會出現。改成沒有組的動作（SwiftData 版本在 `TrainingRegionTests` 本來就有）；同一次的 UI 測試 27 個都通過，改完重跑單元測試 247 個通過後才 commit（App 的程式沒有改）。只修了 1 次，沒有觸發規則 3。
28. §3 的有氧選取測試原本點在 0 分鐘的那一週（那一根沒有長條，截圖看不出選到哪一根），改點第 2 根，單獨重跑圖表的 UI 測試通過後才 commit。
29. Release 的 clean build 用了另一個 derived data 資料夾，放在 repo 根目錄（不在 .gitignore 裡），建置完就刪掉了，沒有 commit。

---

## 7. 未解決的事項
- **沒有觸發規則 3**（沒有任何條件連續修 3 次還過不了）。
- 沒有「先停下來」的情況（第 2 節）。
- 觀察到、照規格做：石墨橙的強調色和上肢的橘很近（有氧長條和訓練頻率的上肢）、石墨藍和石墨青的強調色和下肢的藍很近；石墨銀的「下一次」膠囊外框（銀）和日曆今天的白框顏色接近。規格說靠形狀區分，沒有調整。
- CHANGE_11 留下的兩個 DEBUG 小問題照舊（`-emptyData` 之後再 `-demoData` 沒有輪替順序、`-scrollToBottom 分類` 最後一列在分頁列後面），只影響開發用的參數。

---

## 8. 實機確認清單
1. **橘藍在健身房的燈光下好不好分辨**：本週卡的日曆、圖例、訓練頻率的長條、訓練狀態的圓點；全身的斜分和斜紋看不看得出兩色。也可以打開「設定 › 輔助使用 › 顯示與文字大小 › 增加對比」看系統加強後的藍橘，和「不以顏色區分」看圖例裡的字。
2. **日曆格子的大小好不好讀**：14 pt 的格子、20 週；月份標籤；今天的白框和本週之後的外框；最右邊一欄是本週，和「N 天・N 組」對得上。
3. **推入頁面和滑動返回的手感**：歷程紀錄、動作詳情的歷史和個人紀錄推入的摘要頁；從左邊緣往右滑返回；⋯ 的編輯、再做一次、刪除（刪除後自動回到上一頁）；補登完成後會切到歷程並停在那次的摘要頁。
4. **圖表的顏色會不會太搶眼**：主項進步的迷你折線、體重、有氧的長條（點一下時其他變淡）、動作詳情的折線，換主題後各看一下。
5. **warning 的圖示**：動作庫裡很久沒練的動作、訓練狀態超過 14 天、簽署快到期前面的圖示，會不會太多、太吵。
6. **訓練狀態的輪替列**：不能點之後還需不需要從這裡打開那次訓練。
7. **平衡卡**：以後如果清空資料或換手機，平衡卡寫「還沒有紀錄」。

---

## 9. 截圖索引（`tools/screens/change14/`）
| 檔名 | 內容 | 標準 |
|---|---|---|
| `V1_today.png` | 首頁，沒有訓練：本週卡的點點日曆（20 週）、圖例、膠囊 | V1 |
| `V2_today_active.png` | 首頁，有進行中的訓練：兩張卡都在附屬列上方（UI 測試截取） | V2 |
| `V3_today_<graphiteOrange｜graphiteBlue｜graphitePurple｜graphitePink｜graphiteCyan｜graphiteSilver>.png` | 六個主題的首頁：部位色都相同、強調色不同 | V3 |
| `V4_stats_mainlifts_weight.png` | 主項進步的迷你折線、體重的線和點：強調色 | V4 |
| `V4_stats_cardio_frequency.png` | 有氧長條（強調色）、訓練頻率（部位色、全身斜紋） | V4 |
| `V4_cardio_selected.png`、`V4_cardio_restored.png` | 有氧選取時其他長條變淡、2 秒後恢復（UI 測試截取） | V4 |
| `V4_stats_balance.png` | 平衡卡（有紀錄）：「拉偏少」、9 列 | §5 對照 |
| `V5_detail_chart_peek.png`、`V5_detail.png` | 動作詳情的折線圖：選取時那一點放大和數字（UI 測試截取）；沒有選取時 | V5 |
| `V6_summary_page_top.png`、`V6_summary_page_bottom.png` | 訓練摘要的推入頁面，最上面和捲到最底（UI 測試截取） | V6 |
| `summary_page_from_detail.png` | 從動作詳情「歷史」推入的同一個摘要頁 | §4 |
| `summary_page_editor.png`、`summary_page_deleted.png` | ⋯「編輯」打開編輯訓練；刪除後回到歷程的紀錄 | §4 |
| `training_status_row_tapped.png` | 點了輪替列之後，訓練狀態還開著 | §4 |
| `S_training_status.png` | 訓練狀態浮窗：部位色的圓點、輪替列（只顯示資訊） | §2、§4 |
| `S_settings_appearance.png` | 設定 › 外觀：六個主題的預覽，部位色都是同樣的藍和橘 | §2 |
| `V7_balance_empty.png` | 空資料的平衡卡「還沒有紀錄」 | V7 |
| `V8_today_differentiate.png`、`V8_frequency_differentiate.png` | 系統「不以顏色區分」開啟：格子不放字、圖例有「下」「上」「全」 | V8 |
| `stability_<records｜stats｜library｜category>_1～5.png` | 捲到底部後每 0.5 秒連拍 | 歷程穩定性 |
| `stability_pixel_compare.txt` | 四組都「全部相同」 | 歷程穩定性 |
| `E_today.png`、`E_library.png` | 空資料的首頁、動作庫 | 空狀態 |

---

## 10. commit 列表
```
3852031 CHANGE_14 §5: the balance card says 還沒有紀錄 when there is no record
2b688bb CHANGE_14 §4: the workout summary is a pushed page
838a3f6 CHANGE_14 §3: single-series charts use the accent
7b2acd8 CHANGE_14 §1: the dot calendar is back on the 本週 card
482b1d4 CHANGE_14 §2: body colors are the system blue and orange in every theme
06fd854 CHANGE_14 §0: save the prompt
```
加上最後一個文件 commit（這份報告、SPEC.md、CLAUDE.md、STATUS.md、舊報告的註記、截圖）。
