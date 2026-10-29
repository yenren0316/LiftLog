# CHANGE_12 改用 iOS 26 內建的計時、轉場與標題：最終報告

- 日期：2026-10-29
- 範圍：§0 存原文、CLAUDE.md 加上「每一份 CHANGE 的最後一步」；§1 計時改用系統的計時文字；§2 訓練中畫面的放大轉場；§3「今天」改用系統的大標題。每一節各自 commit，都是建置成功、全部測試通過後才 commit。CLAUDE.md 的執行規則 1～7 照常適用（這次沒有資料遷移，資料模型和備份格式都沒有改）。
- 結果摘要：**§1 完成**。**§2、§3 都遇到 prompt 列出的「先停下來」情況**，照規定維持原樣、沒有自己另寫一套：附屬列裡的橫條不能當放大轉場的來源（第 2 節）；系統的大標題讓首頁超出一個畫面 32.5 pt（第 3 節）。
- 驗證環境：Xcode 27.1（`/Applications/Xcode.app`），iPhone 17 Pro 模擬器（iOS 26.5），測試一律 `-parallel-testing-enabled NO`。最後的截圖在乾淨安裝後用 seed＋示範訓練（`-demoData`），空資料（`-emptyData`）放在最後。這一輪模擬器上沒有匯入過真實資料。
- 文件：`CLAUDE.md`（加上「每一份 CHANGE 的最後一步」；共用做法裡過時的 `.hidesTabBarOnScroll()` 改成交給系統的分頁列）、`SPEC.md`（開頭摘要、共用元件、分頁列與附屬列、今天、訓練中畫面、休息計時器、開發用參數、已移除）、`tools/STATUS.md`、`tools/changes/README.md`（加上 CHANGE_12）已更新；`tools/CHANGE_11_REPORT.md` 第 2 節「自己寫、但 iOS 26 已經內建」的三條建議加了粗體註記。

---

## 1. 收斂標準的結果

### 建置與測試
| 項目 | 結果 | 驗證方式 |
|---|---|---|
| G1 Debug、Release 0 error 0 warning | **通過** | 最後的程式（`154717c`）clean build 三種：Debug（含單元測試和 UI 測試 target，`build-for-testing`）、Release 模擬器（`generic/platform=iOS Simulator`）、Release 實機（`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO`），`grep -c 'error:'`、`grep -c 'warning:'` 都是 0。 |
| G2 全部測試通過 | **通過** | 最後的程式（`154717c`）乾淨安裝後跑全部測試：**258 個全部通過**、0 失敗。單元測試 233（36 檔）＋UI 測試 25（10 檔＋共用）。CHANGE_11 結束時 253 個，這次新增 5 個 UI 測試。 |

G2 要求的新測試：

| 規格要求 | 測試 | 結果 |
|---|---|---|
| 點附屬列的橫條會打開訓練畫面，收合後回到附屬列 | `WorkoutBarUITests.testBarOpensWorkoutAndCollapsesBack`：示範訓練縮小成附屬列的橫條；點橫條打開訓練畫面（看得到經過時間）、按左上角的收合回到附屬列的橫條，訓練畫面關掉；連續兩輪 | 通過（轉場維持原本的 fullScreenCover，見第 2 節） |
| `-demoWorkoutElapsed` 1 小時以上顯示「1:05:30」這種格式 | `TimerTextUITests.testElapsedOverAnHour`：`-demoWorkoutElapsed 3930`，訓練畫面的經過時間符合 `^1:0[56]:\d\d$`，縮小後附屬列的「訓練中 …」也符合 | 通過 |
| 不到 1 小時顯示「24:30」這種格式 | `TimerTextUITests.testElapsedUnderAnHour`：`-demoWorkoutElapsed 1470`，兩個地方都符合 `^2[45]:\d\d$` | 通過 |
| 按「+15 秒」和「跳過休息」後，休息倒數立刻更新 | `TimerTextUITests.testRestCountdownUpdatesRightAway`：`-demoRest 90`；按「+15」後讀到的秒數是之前的 +12～+15（扣掉點擊花的時間）；按「-15」後是 -15～-18；按「跳過」後倒數 1 秒內消失 | 通過 |

其他新增或改寫的測試：
- UI：`TodayLayoutUITests.testTodayFitsOneScreen`（CHANGE_07 的 V1：近 30 天的卡片整張在分頁列上方；量到的空隙存成附件。§3 試大標題時就是這個測試量出差 32.5 pt）。
- 單元：`RestTimerTests` 的三個測試改成直接用結束時間算剩餘秒數（`RestTimer.remaining(at:)` 隨 TimelineView 刪掉，見第 3 節第 3 條）。
- 共用：`allowNotificationsIfAsked()`：休息倒數第一次排通知時系統會問通知權限，對話框會擋住點擊，測試先按「允許」。

### 程式碼檢查
| 項目 | 結果 | 檢查方式 |
|---|---|---|
| S1 ElapsedTimeText、RestTimerBar 不再使用 TimelineView | **通過** | `grep TimelineView` 在 App、共用、小工具裡 0 筆（整個 App 只剩這兩處在用，都改掉了）。沒有維持原樣的地方。 |
| S2 ScreenHeader 沒有殘留的使用 | **不適用（§3 停下來）** | 大標題放不下，照規格停下來，「今天」照舊用 `ScreenHeader`（`TodayView.swift`），所以它還在用、沒有刪。見第 2 節。 |
| S3 新增的 DEBUG 參數都在 `#if DEBUG` 裡 | **通過** | 這次沒有新增參數（§2 實驗用的 `-zoomDemo` 隨實驗一起拿掉，沒有 commit）。腳本列出所有 `UserDefaults.standard.<bool\|string\|integer\|double\|object>(forKey: "字面值")`：39 處（同一個 key 出現多次分開算），全部在 `#if DEBUG` 區塊內。 |

### 畫面驗證（`tools/screens/change12/`）
| 項目 | 結果 | 說明 |
|---|---|---|
| V1 今天分頁使用系統的大標題，一個畫面放得下 | **未通過 → 照規格停下來** | 大標題放不下：`V1_today_large_title_overflow.png`，最後一列「有氧」在分頁列後面，卡片底部 823.5 pt、分頁列頂 791 pt，**差 32.5 pt**。維持原本的標題後 `V1_today.png` 放得下（空隙 20.8 pt，`TodayLayoutUITests` 量的）。 |
| V2 放大轉場的中間畫面、收合回附屬列之後 | **不適用（§2 停下來）** | 中間畫面：`V2_bar_zoom_expand_mid.png`、`V2_bar_zoom_collapse_mid.png` 是以附屬列的橫條當來源時，系統從畫面中間放大、縮回畫面中間（橫條一直在原處）；對照組 `V2_control_card_zoom_*_mid.png` 是同一段程式、來源換成「今天」的卡片，會從卡片放大、縮回卡片。收合之後：`V2_collapsed_to_bar.png`（維持 fullScreenCover，收合後回到附屬列的橫條）。 |
| （每輪重跑）歷程穩定性 | **通過** | 紀錄、統計、動作庫第 1 層、分類清單（核心）各 0.5 秒連拍 5 張，遮掉最上面 200 px 比對都「全部相同」（`stability_pixel_compare.txt`）。 |

截圖逐張看過：沒有不該有的截斷或重疊，顏色都是主題 token（休息倒數的進度條底色是系統的，見第 3 節第 2 條），首頁一個畫面放得下（沒有進行中的訓練時）。

---

## 2. 第 1～3 節有沒有遇到「先停下來」的情況

### §1 計時：沒有
系統的計時文字做得到相同的格式和行為，所有地方都改了：
- 經過時間 `ElapsedTimeText`：`Text("\(prefix)\(Text(timerInterval: since...Date.distantFuture, countsDown: false))")`。用在訓練畫面的頂部、附屬列的「訓練中 0:42」（展開時兩行、縮小時一行，兩種都是它）。
- 休息倒數 `RestTimerBar`：`Text("休息 \(Text(timerInterval: start...end, countsDown: true))")` 和 `ProgressView(timerInterval: start...end, countsDown: true)`（區間是休息開始到結束）。「+15」「-15」「跳過」改的是 `RestTimer` 的結束時間，畫面換一個區間，所以立刻更新；跳過時區間沒了，整條消失。
- 格式在模擬器上實測：暫時在訓練畫面放了 7 種寫法加框線比較（看完拿掉），顯示「0:43」「1:07:25」；UI 測試的截圖是「24:36」「1:05:36」。和以前 `WorkoutSession.format(duration:)` 一樣。計時文字的寬度剛好是顯示的字，沒有預留最長格式的空間（上限用 `Date.distantFuture` 也一樣），位置和以前相同。
- 其他顯示經過時間或倒數的地方本來就是系統的計時文字：小工具（`Text(startedAt, style: .timer)`）、即時動態和動態島（`Text(timerInterval:)`、`ProgressView(timerInterval:)`、`WorkoutActivityElapsedTime`）。完成摘要和歷程的「75 分」是固定的時長，不會跳動，不在範圍內。App 裡沒有其他 `TimelineView`、`Timer.publish`。

### §2 放大轉場：**有，附屬列不支援 matchedTransitionSource**
做法：`RootView` 一個 `@Namespace`；附屬列的橫條 `.matchedTransitionSource(id: "workoutMiniBar", in: namespace)`；`fullScreenCover` 的內容只在「從橫條點開」時加 `.navigationTransition(.zoom(sourceID: "workoutMiniBar", in: namespace))`，其他入口照原本的方式。

查法：模擬器沒有手可以點、UI 測試的截圖又會等動畫結束，所以加了暫時的 DEBUG 參數，讓 App 自己照「點橫條」的做法展開再收合，用 `simctl io recordVideo` 錄影、`ffmpeg` 每秒 30 格取出畫面。三種來源各錄一次：

| 來源 | 展開 | 收合 | 截圖 |
|---|---|---|---|
| 附屬列的橫條（Button） | 從畫面中間放大，橫條一直顯示在原處 | 縮回畫面中間、淡出，不是縮回橫條 | `V2_bar_zoom_expand_mid.png`、`V2_bar_zoom_collapse_mid.png` |
| 附屬列橫條裡面的內容（HStack） | 同上 | 同上 | （和上面一樣，沒有另外存） |
| 對照組：「今天」的「下一次」卡（同一段程式，只換來源） | 從卡片的位置放大，卡片在轉場中隱藏 | 縮回卡片 | `V2_control_card_zoom_expand_mid.png`、`V2_control_card_zoom_collapse_mid.png` |

從畫面中間放大、來源不隱藏，是 zoom 轉場找不到來源時的預設行為。對照組證明轉場本身接得對，問題在附屬列：`tabViewBottomAccessory` 的內容由系統另外放在分頁列裡，轉場找不到放在裡面的來源。所以照 §2 的規定停下來，**維持原本的 fullScreenCover** **（CHANGE_15 §3 推翻：訓練畫面改成全高的 sheet，往下拖縮小到附屬列；放大轉場照舊沒有。）**（點橫條從下往上打開、按收合往下關，回到附屬列的橫條），程式恢復成修改前的狀態，只留下 UI 測試和截圖。fullScreenCover 沒有往下拖關閉的手勢；那是放大轉場附帶的行為，沒有自己另外加。

之後的 iOS 如果讓附屬列能當來源，改法就是上面三行（namespace、`matchedTransitionSource`、只在從橫條點開時加 `navigationTransition(.zoom)`，關掉後重設「從橫條點開」的旗標），測試 `WorkoutBarUITests` 可以直接沿用。

### §3 大標題：**有，首頁放不下，差 32.5 pt**
做法：拿掉 `ScreenHeader(title: "今天")` 和 `.toolbar(.hidden, for: .navigationBar)`，改成 `.navigationTitle("今天")`＋`.navigationBarTitleDisplayMode(.large)`。

量法：`TodayLayoutUITests` 量「近 30 天」卡片的底部和分頁列的頂部（iPhone 17 Pro 模擬器、示範資料、沒有進行中的訓練）。

| 標題 | 卡片底部 | 分頁列頂部 | 空隙 |
|---|---|---|---|
| 原本的 `ScreenHeader` | 770.2 pt | 791 pt | **+20.8 pt**（放得下） |
| 系統的大標題 | 823.5 pt | 791 pt | **−32.5 pt**（最後一列「有氧」在分頁列後面） |

系統的大標題上面還有一列空的導覽列（導覽列底部在 168 pt），整頁往下推了 53.3 pt。截圖：`V1_today_large_title_overflow.png`。照 §3 的規定停下來，**「今天」照舊用 `ScreenHeader`**（還在用，所以沒有刪）。**（CHANGE_13 §2-5 推翻：首頁精簡成「下一次」和「本週」兩張卡之後，系統的大標題放得下——沒有訓練時離分頁列 216.5 pt、有附屬列時 182.5 pt；`ScreenHeader` 已刪掉。）**

如果還是想要系統的大標題，需要你決定從哪裡省出至少 33 pt，例如：近 30 天每列的最小高度從 24 pt 降到 20 pt（9 列省 36 pt）、縮小卡片之間的間距和卡片內距、或接受首頁要捲一點點。這些都會改到 CHANGE_07 定下的版面，這次沒有動。

---

## 3. 自行決定的事項

**§0**
1. CLAUDE.md 的「每一份 CHANGE 的最後一步」照錄，另外在「另外每一輪都照做」加一條指過去；順便把共用做法裡已經刪掉的 `.hidesTabBarOnScroll()`（CHANGE_11 §1）改成「分頁列交給系統」。

**§1 計時**
2. 休息倒數的進度條用系統的 `ProgressView(timerInterval:)`，顏色用 `.tint(Theme.accent)`；底色和粗細是系統的（比以前的 `ThinBar` 細一點，底色是系統的灰），沒有自己再畫一條，照「能用內建的就不要自己寫」。
3. `RestTimer.remaining(at:)` 只有 TimelineView 在用，改完之後只剩測試在用，照 CHANGE_11 的做法刪掉；`RestTimerTests` 改成直接用結束時間算。
4. 經過時間的區間上限用 `Date.distantFuture`，忘了結束的訓練也會一直往上算（和以前一樣），不會停在某個上限。
5. 倒數在整秒之間怎麼進位由系統決定（以前是無條件進位）；測試只確認「+15」「-15」後的秒數在合理的範圍、「跳過」後立刻消失。
6. 經過時間和休息倒數加了 UI 測試用的 identifier（`elapsedTime`、`restCountdown`），不影響畫面。

**§2 放大轉場**
7. 放大只打算用在「從橫條點開」；「下一次」卡、小工具、深層連結照原本的方式（規格的要求）。因為停下來了，最後全部都是原本的方式。
8. 錄影查轉場：試過用 window 的 `layer.speed` 把動畫放慢 10 倍，轉場的速度沒有變（約 0.5 秒），改用 30 fps 錄影取畫面。實驗用的 DEBUG 參數和程式都沒有 commit。

**§3 大標題**
9. 停下來後，保留量版面的 UI 測試（`TodayLayoutUITests`），當作 CHANGE_07 V1 的回歸測試；「近 30 天」卡片加了 identifier `recentSetsCard`。

---

## 4. 未解決的事項
- **沒有觸發規則 3**（沒有任何條件連續修 3 次還過不了）。
- §2、§3 照 prompt 的規定停下來（第 2 節），不算未解決，但這兩節的目標沒有達成：訓練中畫面沒有放大轉場、「今天」沒有用系統的大標題，需要你決定之後怎麼處理（§3 的選項在第 2 節最後）。
- 觀察到、不在這次範圍：有進行中的訓練時，附屬列的橫條會蓋住「近 30 天」最後一列（`V2_collapsed_to_bar.png`），要往下捲才看得到。**（CHANGE_13 §2 已處理：近 30 天卡從首頁拿掉，兩張卡在附屬列上方 182.5 pt。）**CHANGE_11 把橫條移到系統的附屬列之後就是這樣；CHANGE_07 的 V1 是沒有訓練時的標準。
- CHANGE_11 留下的兩個 DEBUG 小問題照舊（`-emptyData` 之後再 `-demoData` 沒有輪替順序、`-scrollToBottom 分類` 最後一列在分頁列後面），只影響開發用的參數。

---

## 5. 實機確認清單
1. **計時跳秒是否順暢**：訓練畫面頂部的經過時間、附屬列的「訓練中」（分頁列展開和縮小兩種）、休息倒數的數字和進度條，每秒都有跳、沒有卡頓或跳兩秒；超過 1 小時顯示「1:05:30」，不到 1 小時「24:30」。
2. **休息倒數的操作**：按「+15」「-15」數字和進度條立刻變；按「跳過」整條立刻消失；倒數結束時震動、整條消失；App 到背景再回來，倒數照樣準確。
3. **進度條的樣子**：休息倒數的進度條改成系統的（比以前細一點、底色是系統的灰），看起來可以接受嗎？
4. **耗電**：訓練中（尤其是休息倒數時）放著不動一段時間，和以前比較耗電有沒有變少（以前畫面每 0.5～1 秒整塊重畫）。
5. **附屬列的橫條**：點一下打開訓練畫面、按左上角收合回到橫條（這次維持原本的動畫，沒有放大轉場；也沒有往下拖關閉）。
6. **即時動態和動態島**：這次沒有改，經過時間和倒數照舊。

---

## 6. 截圖索引（`tools/screens/change12/`）
| 檔名 | 內容 | 標準 |
|---|---|---|
| `V1_today.png` | 乾淨安裝＋示範資料的今天（原本的標題）：近 30 天整張在分頁列上方 | V1 |
| `V1_today_large_title_overflow.png` | 改成系統的大標題時：最後一列「有氧」在分頁列後面，差 32.5 pt | V1（停下來的原因） |
| `V2_bar_zoom_expand_mid.png` | 以附屬列的橫條當來源的放大轉場（錄影的一格）：從畫面中間放大，橫條還在原處 | V2（停下來的原因） |
| `V2_bar_zoom_collapse_mid.png` | 同上，收合時縮回畫面中間，不是縮回橫條 | V2（停下來的原因） |
| `V2_control_card_zoom_expand_mid.png` | 對照組：來源換成「下一次」卡，從卡片放大 | V2（對照） |
| `V2_control_card_zoom_collapse_mid.png` | 對照組：縮回卡片 | V2（對照） |
| `V2_collapsed_to_bar.png` | 維持 fullScreenCover：收合之後回到附屬列的橫條（UI 測試截取） | V2 |
| `G2_elapsed_over_an_hour.png` | `-demoWorkoutElapsed 3930`：經過時間「1:05:36」 | G2 |
| `G2_elapsed_under_an_hour.png` | `-demoWorkoutElapsed 1470`：經過時間「24:36」 | G2 |
| `G2_rest_countdown.png` | 休息倒數「休息 1:22」和系統的進度條 | G2 |
| `stability_<紀錄 records｜統計 stats｜動作庫 library｜分類 category>_1～5.png` | 捲到底部後每 0.5 秒連拍 | 歷程穩定性 |
| `stability_pixel_compare.txt` | 四組都「全部相同」 | 歷程穩定性 |
| `E_today.png` | 空資料的今天 | 空狀態 |

---

## 7. commit 列表
```
154717c CHANGE_12 §3: keep ScreenHeader; the system large title does not fit
c2dd20a CHANGE_12 §2: keep the full-screen cover; the accessory is not a zoom source
ab94b6a CHANGE_12 §1: elapsed time and rest countdown use the system timer text
8197074 CHANGE_12 §0: save the prompt; CLAUDE.md gets the re-signing last step
```
加上最後一個文件 commit（這份報告、SPEC.md、STATUS.md、截圖）。
