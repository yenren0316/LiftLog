# LiftLog 現況報告（STATUS）

> **CHANGE_07～09 的資訊架構重整已收斂**：三次的收斂標準都通過，CHANGE_09 的實機確認也全部通過。收斂時的版本打了 git tag `v1.0-ia`（`f4ba90c`）。
>
> 觀察到、還沒處理的三項待辦（細節在 `tools/CHANGE_09_REPORT.md` 第 2 節）：
> 1. **灰格子的計算口徑**：日曆的灰色格子（有氧與其他）有的算進次數、有的不算。「只有有氧的訓練也算」關閉時，只有有氧的日子照樣上色但不算；只有核心或補強的日子算。（第 15、16 條）CHANGE_13 起日曆拿掉了，同樣的口徑在「本週」卡的灰色圓點；CHANGE_14 起是「本週」卡點點日曆的灰色格子。
> 2. ~~**每週目標沒有進備份**：每週目標和「只有有氧的訓練也算」存在 UserDefaults，匯出的 JSON 沒有這兩個設定，重裝後要重新設定。（第 11 條）~~ **CHANGE_11 §8 已處理：備份 version 7 包含所有設定。**
> 3. **平均值涵蓋一段沒畫出來的週**：訓練頻率卡只畫 12 條（含本週），平均用本週之前的 12 個週或月，最舊的那一段算進平均但沒有畫出來。（第 2 條）

- 更新時間：2026-10-29，對應 CHANGE_15 完成後的 main（commit `8563e86` 之後的文件 commit）。上一版是 CHANGE_14 完成時。
- CHANGE_10（實機回饋修正、首頁日曆改版、鍵盤收合與點擊提示統一）、CHANGE_11（改用 iOS 26 內建行為、跨日重算、清除舊程式、真實資料驗證）、CHANGE_12（系統的計時文字；放大轉場和系統大標題照規格停下來）、CHANGE_13（首頁兩張卡和系統大標題、設定移到右上角、顏色語意、動作庫精簡）、CHANGE_14（點點日曆回到本週卡、部位色改成系統藍橘、圖表上色、訓練摘要改成推入頁面、平衡卡的空狀態）和 CHANGE_15（標題和按鈕同一列、建立菜單一個畫面、訓練畫面往下拖縮小、觸覺與新紀錄）在 `v1.0-ia` 之後，完整結果在 `tools/CHANGE_10_REPORT.md`～`tools/CHANGE_15_REPORT.md`。
- 對象：負責 review 和規劃、看不到程式碼的人。內容根據實際程式碼、建置、測試與模擬器截圖整理。
- 平台：iOS 26、SwiftUI＋SwiftData，App 只給自己用，用免費 Apple ID 安裝。
- 規模：App＋共用＋小工具約 12,600 行 Swift，單元測試約 4,700 行（261 個）、UI 測試約 1,270 行（41 個）。
- CHANGE_07 開始前的版本打了 git tag `before-change07`（`6f72de3`）。
- 各次的完整驗收結果、自行決定的事項和實機確認清單在 `tools/CHANGE_07_REPORT.md`～`tools/CHANGE_15_REPORT.md`。

---

## 1. 進度總覽

### 1-1. 文件來源
- CHANGE_06～15 的原文在 `tools/changes/`（06～10 從對話紀錄還原，11～15 照錄）；CHANGE_01～05 的原文不在 repo 裡，也還原不了，重點整併在 `SPEC.md`（開頭有每份 CHANGE 的一行摘要）。專案的固定規則在根目錄的 `CLAUDE.md`。
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
| CHANGE_10 | §0-1 圖表擋住捲動、§0-2 分頁列收起一致、§0-3 捨棄訓練與 alert、§0-4 動態島經過時間、§0-5 DE 建議重量、§0-6 上一次、§0-7 只顯示角色、§1 鍵盤收合、§2 首頁日曆、§3 訓練狀態浮窗、§4 點擊提示統一 | 完成 | 收斂標準 G1、G2、S1–S7、V1–V8 都通過；0-1、0-2、0-5、0-6 的原因見報告第 2 節 |
| CHANGE_11 | §1 分頁列與訓練中橫條改用系統、§2 日期改變時重算、§3 1RM 統一與清除舊程式、§4 鍵盤（4-1 收鍵盤、4-2 候選列）、§5 圖表行為統一、§6 動態島日型簡稱、§7 訓練狀態浮窗高度、§8 備份加入設定、§9 真實資料驗證 | 完成 | G1、G2、S1–S5、V1–V3、V5、R1 通過；§4-2 的候選列融不進 iOS 26 的鍵盤，照規格拿掉（V4 和候選列的兩項測試因此不適用，見報告第 5 節） |
| CHANGE_12 | §0 CLAUDE.md 加上最後一步（更新簽署、安裝到 iPhone）、§1 系統的計時文字、§2 訓練中畫面的放大轉場、§3「今天」的系統大標題 | §1 完成；§2、§3 照規格停下來（§3 在 CHANGE_13 完成） | G1、G2、S1、S3、歷程穩定性通過；§2 附屬列不能當放大轉場的來源，維持 fullScreenCover（V2 不適用）；§3 大標題讓首頁超出 32.5 pt，維持 ScreenHeader（V1 用原本的標題通過、S2 不適用）。見報告第 2 節 |
| CHANGE_13 | §0 存原文、§2 首頁兩張卡（下一次、本週）和系統大標題、§1 設定移到右上角的 sheet（分頁剩三個）、§3 顏色語意（部位色、強調色、不用紅綠燈、對比度、訓練名稱、不只靠顏色）、§4 動作庫只顯示動作數 | 完成；本週卡的圓點、每個主題的部位色、中性色的圖表、摘要浮窗在 CHANGE_14 改掉 | G1、G2（269 個）、S1–S5、V1–V8、歷程穩定性、R1 都通過；沒有遇到「先停下來」。見報告 |
| CHANGE_14 | §0 存原文、§2 部位色改成系統藍橘（六個主題共用）和 warning 加圖示、§1 點點日曆回到本週卡、§3 單一數列的圖表用強調色、§4 訓練摘要改成推入的頁面、§5 平衡卡的空狀態 | 完成；完成畫面的全螢幕和補登的兩步在 CHANGE_15 改掉 | G1、G2（281 個）、S1–S6、V1–V8、歷程穩定性、R1 都通過；沒有遇到「先停下來」（日曆用 14 pt 的格子：離分頁列 117.5 pt、離附屬列 83.5 pt）。見報告 |
| **CHANGE_15** | §0 存原文、§1 標題和右上角的按鈕同一列（inlineLarge）、§2 建立菜單合成一個畫面（補登也用它）、§3 訓練畫面改成可以往下拖縮小的 sheet、§4 觸覺（.sensoryFeedback）與新紀錄（估算 1RM） | **完成** | G1、G2（302 個）、S1–S6、V1–V7、歷程穩定性、R1 都通過；第 1～3 節都沒有遇到「先停下來」（首頁多出 52 pt：離分頁列 169.5 pt、離附屬列 135.5 pt）。見報告 |

### 1-3. 實作和文件不一樣的地方
CHANGE_15（完整清單在 `tools/CHANGE_15_REPORT.md` 第 5 節）：
- 動作庫的搜尋列和第一個分區之間是 List 預設的上方間距（離導覽列 35 pt），標題改成同一列之後看起來比以前空一點；照規格交給系統，沒有調。
- 建立菜單：「換日型」是日型旁邊的 Menu，只列其他三個；動作數的分段寫「1 個」「2 個」「3 個」；有氧那一格固定跑步機、不能點；候選的小字：建議的是「建議・原因」，其他是幾天前（「12 天前」「還沒練過」）；換過的格子也寫幾天前、不再是 accent。原因放得下 Menu（最長兩行），沒有做候選清單頁。
- 「改動作數、跑步機時保留手動換過的格子」也套用到換某一格（主項換成拉的動作時，換過的「拉」丟掉）。
- 補登的日期和時間放在建立菜單畫面最上面的卡片，「不照建議，自由選動作」也是補登；`BackfillSheet` 刪掉。
- 新紀錄只有重量型的動作有（估算 1RM 只定義在重量型）：以前輔助型「輔助重量創新低」、自重型的最多次數也算，現在不算；負的重量（輔助引體向上）也沒有估算 1RM。相等用 1e-6 的誤差判斷。
- 完成訓練的 success 觸覺在完成畫面出現時；有新紀錄時獎盃同時彈，只震一次。休息倒數結束本來就是 `.sensoryFeedback(.success)`，沒有改。

CHANGE_14（完整清單在 `tools/CHANGE_14_REPORT.md` 第 6 節）：
- 實作順序是 §2 → §1 → §3 → §4 → §5（日曆要用 §2 的部位色），每一節各自 commit。
- 日曆的格子用 14 pt（範圍的上限）：兩種狀態都放得下，不用縮到 12 pt。iPhone 17 Pro 是 20 週。最右邊一欄的月份字靠右，不超出日曆。
- 今天的外框是格子外面一圈主要文字色（2.5 pt 外、1.5 pt 粗）；本週之後的日子是 field 色的外框。
- 全身的斜紋（訓練頻率）要先依畫面的環境解析兩個系統色再畫成圖案（`RegionStripes`），增加對比時也跟著換。
- warning 審查時把所有 warning 色的文字改成 `Text.warning`（前面加 `exclamationmark.circle`），包括「N 天前」超過 60 天、訓練狀態超過 14 天、簽署快到期、結束時間錯誤、同一天已有體重；平衡卡和安全提示本來就有文字或圖示。
- 體重圖：每天的點和細線是淡的強調色，7 日平均是實色的粗線；圖例的線是強調色、字是中性色。
- 訓練摘要是推入的頁面，打破「第 3 層不再 push」：動作庫 → 分類 → 動作詳情 → 摘要是第 4 層（規格要求在各自的 NavigationStack 推入）；摘要頁本身不再往下推。CLAUDE.md 的設計原則加了這個例外。
- 補登和 `-openSummary` 這類從別的地方打開的摘要：切到歷程，路徑換成只有摘要頁（返回是歷程的第 1 層）。刪除是先返回、頁面消失後才刪。
- 「再做一次」改成由 RootView 確認（頁面不是 sheet，不用等浮窗關掉）；開始後展開訓練畫面，收合後回到摘要頁。
- 摘要頁的刪除測試用新的 `-demoDeletable YES` 加一筆「刪除測試」，不刪示範資料。

CHANGE_13（完整清單在 `tools/CHANGE_13_REPORT.md` 第 5 節）：
- 「下一次」卡的 DE（爆）主項只寫名稱；DE 速度主項沒有可以計算的紀錄時也只寫名稱（不放「用能做得很快的重量」）。整張卡是一個按鈕，「開始」只是主要按鈕的外觀。
- 輪替膠囊排成兩排（ME 一排、DE 一排）。提醒的日期用訓練的開始日期、包括封存的動作，天數一樣多時取分類順序在前的。
- 設定的 sheet 在換主題時不會關掉，會停在「外觀」；關閉按鈕只在第 1 層。sheet 開著時的深層連結先關掉 sheet 再導向。
- neglectedDays 和本週卡的提醒口徑相反（取最舊 vs 取最新），不能沿用，刪掉；提醒用新的 `categoryLastDates`。
- 強調色審查時改成中性的地方（圖表、個人紀錄、統計數字、角色標記、休息倒數的外框和進度條、熱身組號、「新」）；有氧卡選取的那一根長條用 accent。超過 60 天沒練是 warning，其他「N 天前」中性。封存的滑動按鈕照舊 warning。
- 訓練狀態浮窗原本沒有部位色，加了下肢、上肢前面的圓點。小工具和即時動態的顏色照舊。
- 石墨藍的上肢色（橘，離 warning 18 度）和石墨粉的上肢色（離新的下肢色 50 度）換掉；textSecondary 都超過 4.5:1，沒有改。

CHANGE_12（完整清單在 `tools/CHANGE_12_REPORT.md` 第 2、3 節）：
- §2 沒有放大轉場：`tabViewBottomAccessory` 裡的橫條不能當 `matchedTransitionSource`（轉場只會從畫面中間放大），訓練中畫面照舊是 fullScreenCover，也沒有往下拖關閉。
- §3 沒有系統的大標題：會讓首頁超出一個畫面 32.5 pt，「今天」照舊是 `ScreenHeader`（所以 ScreenHeader 沒有刪）。要改需要先決定從哪裡省出高度。**（CHANGE_13 §2-5 已改用系統的大標題，ScreenHeader 刪掉。）**
- 休息倒數的進度條是系統的 `ProgressView`（accent 色，底色和粗細是系統的），不再是 `ThinBar`。
- `RestTimer.remaining(at:)` 刪掉（只剩測試在用）。

CHANGE_11（完整清單在 `tools/CHANGE_11_REPORT.md` 第 6 節）：
- 候選列（§4-2）融不進 iOS 26 的鍵盤，照規格拿掉；鍵盤上方沒有任何列，可以記負數的動作的重量欄改用有負號的鍵盤。實作留在 commit `c0ac0e7`。
- 分頁列：模擬器上系統只在捲回頂端時恢復（不是中途往上捲就恢復），照規格交給系統。iOS 26.0 沒有 `tabViewBottomAccessory(isEnabled:)`，沒有訓練時不加附屬列。
- 「現在」記在統計快照裡，「N 天前」、日曆、有氧卡都用它；`-fakeNow` 只影響統計，不影響記錄用的時間。
- 主項進步卡的「和 4 週前相比」改用同一個估算 1RM 函式（90 天內沒有就取全期），以前顯示「一樣」的有些會出現差距。
- 備份的設定不含畫面的記憶（歷程的分段、排序、週／月）；每週目標沒設定過寫 null。
- 訓練狀態浮窗量到內容高度之前先用半高（打開的一瞬間）。

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

### 1-4. git log 摘要（共 129 筆，新 → 舊；不含這次的文件 commit）
```
8563e86 CHANGE_15 §4: system haptics and estimated-1RM new records
7e41e31 CHANGE_15 §3: the workout screen is a sheet you can drag down
aea233f CHANGE_15 §2: the plan is one screen
f6f284b CHANGE_15 §1: title and toolbar button share one row (inlineLarge)
e0e89e6 CHANGE_15 §0: save the prompt
27c762f CHANGE_14: report, SPEC, CLAUDE.md and STATUS updates, verification screenshots
3852031 CHANGE_14 §5: the balance card says 還沒有紀錄 when there is no record
2b688bb CHANGE_14 §4: the workout summary is a pushed page
838a3f6 CHANGE_14 §3: single-series charts use the accent
7b2acd8 CHANGE_14 §1: the dot calendar is back on the 本週 card
482b1d4 CHANGE_14 §2: body colors are the system blue and orange in every theme
06fd854 CHANGE_14 §0: save the prompt
d0e2e53 CHANGE_13: report, SPEC and STATUS updates, verification screenshots
ce82203 CHANGE_13 §4: library category rows show only the exercise count
bdfd6cc CHANGE_13 §3: one meaning per color; body colors per theme
43d04bc CHANGE_13 §1: settings open from the gear on Today; three tabs
f95faa9 CHANGE_13 §2: Today is two cards — next workout and this week
8bce15c CHANGE_13 §0: save the prompt
427f77e CHANGE_12: report, SPEC and STATUS updates, verification screenshots
154717c CHANGE_12 §3: keep ScreenHeader; the system large title does not fit
c2dd20a CHANGE_12 §2: keep the full-screen cover; the accessory is not a zoom source
ab94b6a CHANGE_12 §1: elapsed time and rest countdown use the system timer text
8197074 CHANGE_12 §0: save the prompt; CLAUDE.md gets the re-signing last step
7200b7a CHANGE_11: report, SPEC and STATUS updates, verification screenshots
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
f41ba35 Project rules in CLAUDE.md; CHANGE_06–10 originals restored
d8ab578 CHANGE_10: report, SPEC and STATUS updates, verification screenshots
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
（更早 58 筆見上一版 STATUS 或 `git log`）
```

---

## 2. 畫面清單

> 共通：顏色都走主題 token（`Theme.*`），App 固定深色；按鈕高度和膠囊高度走 `Metrics`（50／38）。
> 層級：第 1 層分頁、第 2 層 push、第 3 層唯讀 sheet；例外是訓練摘要（CHANGE_14 §4 起是推入的頁面）。

**2-1. 分頁殼與訓練中橫條**（`Views/RootView.swift`、`Views/Workout/WorkoutCoordinator.swift`）
- 3 個分頁：今天、歷程、動作庫（`AppTab` enum；CHANGE_13 §1 起設定是「今天」右上角齒輪打開的 sheet，RootView 呈現，放在換主題重建的範圍外面）。第 1 層的標題都是 `.inlineLarge`：大字的標題和右上角的按鈕同一列（CHANGE_15 §1）。有進行中的訓練時，系統的附屬列（`tabViewBottomAccessory`）有「訓練中 m:ss」橫條：分頁列展開時在上方兩行、縮小時同一列一行，點一下打開訓練畫面（CHANGE_11 §1）。經過時間是系統的計時文字（CHANGE_12 §1）。訓練畫面 CHANGE_15 §3 起是全高的 sheet，往下拖＝收合；沒有放大轉場（附屬列不能當來源，CHANGE_12 §2）。
- RootView 也負責：建立菜單 sheet、訓練狀態浮窗、設定的 sheet（開著時收到深層連結先關掉）、訓練畫面與完成畫面的 sheet、開始訓練的確認對話框、深層連結導向、啟動時的匯入與資料遷移。
- 分頁列全部交給系統（CHANGE_11 §1）：`.tabBarMinimizeBehavior(.onScrollDown)`，往下捲縮小、捲回頂端恢復（模擬器上量到的系統行為）；動作詳情不再隱藏分頁列。CHANGE_08～10 自己寫的收起邏輯都刪掉了。
- 確認一律用置中的 alert；可以點的卡片和列整塊可點、按下時換成按壓色，沒有「›」。

**2-2. 今天**（`Views/Today/TodayView.swift`、`Logic/TodayCards.swift`）
- CHANGE_13 §2：系統的大標題「今天」、右上角齒輪（設定）、兩張卡，一個畫面放得下。CHANGE_15 §1 起標題和齒輪同一列：沒有訓練時本週卡底部離分頁列 169.5 pt、有附屬列時 135.5 pt（CHANGE_14 是 117.5、83.5 pt，`TodayLayoutUITests`）。沒有第 2 層。
- 「下一次」卡：日型、主項一行（DE 速度「主項：臥推（速度）・建議 32.5 kg」，建議重量和建立菜單同一個 `SlotAdvice`；ME「做到 3RM」；沒有候選「主項：—」）、「3 個動作・跑步機 30 分鐘」、全寬的「開始」→ 建立菜單（WorkoutLauncher）。訓練中時改成「進行中」、名稱、經過時間、「繼續」→ 訓練畫面。
- 「本週」卡：「N 天・N 組」（訓練狀態的本週）、點點日曆（CHANGE_14 §1：每一欄一週、最右邊一欄是本週，iPhone 17 Pro 20 週；依部位上色，下肢系統藍、上肢系統橘；今天外面一圈白框；本週之後只有外框；月份標在每個月第一個週一）和圖例（「不以顏色區分」時圖例加字）、輪替四個膠囊（練過的勾勾、「下一次」外框）、超過 14 天沒練的分類提醒（warning 加圖示）。整張卡打開「訓練狀態」浮窗（`TrainingStatusSheet`：本週、上週同期、四列輪替（CHANGE_14 起只顯示資訊、不能點）；下肢和上肢前面有部位色圓點）。
- CHANGE_13 刪掉：訓練日曆卡、近 30 天卡（組數搬到歷程的平衡卡）、分類待練清單、`ScreenHeader`。
- 空資料：「ME 下肢」「主項：—」「3 個動作」、本週 0 天 0 組、日曆全是沒練的格子、膠囊沒有勾勾；訓練狀態每列「還沒練過」。

**2-3. 建立菜單**（`Views/Plan/PlanSheet.swift`、`Logic/PlanMenu.swift`，sheet；CHANGE_15 §2 起一個畫面）
- 大字的日型＋「換日型」的 Menu（其他三個）；動作數 1／2／3 的分段和「跑步機 30 分鐘」的開關；每一格一列（角色、建議的動作、原因、處方「8 組 × 3 下・建議 32.5 kg（60%）」、安全提示），點一格是系統的 Menu（前 5 個候選，每個下面一行小字：建議的原因或幾天前，目前選的打勾）；最後是「不照建議，自由選動作」；最下面固定「開始訓練」。「開始」→「開始訓練」兩下就開始。改日型全部重算，改動作數、跑步機保留手動換過、還在的格子。左上角系統的關閉，也可以往下拖關閉。
- 補登（歷程 ⋯）也是這個畫面：最上面多一張日期、開始、結束時間的卡片，按鈕「補登這次訓練」。
- 有進行中的訓練時：進來前先問「繼續目前訓練／建立新菜單」，按開始時才確認結束舊訓練。

**2-4. 訓練中**（`Views/Workout/WorkoutView.swift`、`WorkoutEditor.swift`，CHANGE_15 §3 起是全高的 sheet，往下拖收合到附屬列）
- 標題欄位（自動名稱、恢復自動名稱；return 收起鍵盤）、經過時間、休息計時、動作卡片與組。經過時間和休息倒數（數字和進度條）是系統的計時文字，系統自己跳秒（CHANGE_12 §1）；「+15」「-15」「跳過」立刻更新。點動作名稱開唯讀說明 sheet。卡片標題旁只有這次的角色；「上一次」同角色優先，沒有時加角色小字（「40×3・ME」）；DE 速度主項「建議 55 kg（60%）」並灰字預填。最底部紅字「捨棄訓練」（置中的確認）。
- 鍵盤上方沒有任何列（CHANGE_11 §4：-2.5／+2.5／+5、±、下一格、完成拿掉；候選列試過但融不進 iOS 26 的鍵盤）；可以記負數的動作的重量欄用有負號的鍵盤。
- 完成後的摘要（`WorkoutSummaryView`）有選填的「今天體重」，輸入時捲到中間；不能往下拖關閉（CHANGE_15 §3）。有新紀錄時最上方是「新紀錄」區塊（動作、新的估算 1RM、之前最好的，獎盃彈一次）（CHANGE_15 §4）。觸覺：打勾輕的 impact、完成 success、休息結束 success，都是 `.sensoryFeedback`。全 App 的鍵盤：點空白處（訓練畫面的組與組之間、說明列、動作標題也算）、往下捲、按主要按鈕都會收起。

**2-5. 歷程**（`Views/History/HistoryView.swift`、`HistoryStatsView.swift`）
- 大字的標題「歷程」和右上的 ⋯（「補登訓練」）同一列（CHANGE_15 §1），下面是分段「紀錄｜統計」。
- 紀錄：依月份分組「2026 年 10 月・19 次」，每列日、星期、名稱、時長與動作數 → 推入訓練摘要頁（CHANGE_14 §4）。
- 統計：主項進步、體重、有氧、訓練頻率（週｜月的長條圖，以天為單位、依部位色疊色；虛線平均只算過完的週或月；「週」有一條實線是每週目標；標題列「本週 2/3・近 12 週平均 M 次」）、平衡（推拉比、單邊、爆發，CHANGE_13 起加上近 30 天 9 個分類的中性長條，不能點；「拉偏少」「0 沒練」是 warning；CHANGE_14 §5 起完全沒有紀錄時只寫「還沒有紀錄」）五張卡。CHANGE_14 §3 起單一數列的圖表（主項進步、體重、有氧）用強調色，有氧選取時其他長條變淡；訓練頻率用部位色；數字是中性色。所有圖表同一套選取（CHANGE_11 §5）：點一下浮出數字、2 秒後消失；按住 0.2 秒後拖曳跟著手指、放開 2 秒後消失；上下滑交給捲動。

**2-6. 訓練摘要頁**（`WorkoutSummaryPage.swift`，CHANGE_14 §4 起是推入的頁面，不是 sheet）
- 從歷程的紀錄、動作詳情的歷史和個人紀錄在各自的 NavigationStack 推入；補登和 `-openSummary` 切到歷程再推入。全高、系統的返回、左邊緣往右滑返回。
- 名稱、日期、「18:30–19:45・75 分」、體重；每個動作的角色、新紀錄的小獎盃（CHANGE_15 §4，和完成畫面同一個 `NewRecords.find`）、組；備註。
- ⋯：編輯（全螢幕 `SessionEditorView`：名稱、日期、開始與結束時間、未記錄時間的「設定時間」、動作卡片；按「完成」時有填了數字但沒打勾的組先詢問「把 N 組標為完成／保持未完成／繼續編輯」）、再做一次、刪除（置中的確認，刪除後返回上一頁）。

**2-7. 補登訓練**（CHANGE_15 §2 起是建立菜單的畫面 `PlanSheet`，`BackfillSheet` 刪掉）
- 最上面是日期、開始、結束時間，下面和建立菜單一樣；「補登這次訓練」或「不照建議，自由選動作」→ 建立已結束的訓練，切到歷程、推入摘要頁並進入編輯。

**2-8. 體重**（`BodyWeightViews.swift`）
- 體重卡（最新、近 30 天變化、範圍、折線＋7 日平均，CHANGE_14 起是強調色）、記錄體重 sheet（同一天覆蓋前確認）、從健康 App 帶入（多選）。

**2-9. 動作庫**（`Views/Library/`）
- 第 1 層：9 個分類列（CHANGE_13 §4 起只有「N 個動作」）＋已封存；大字的標題和右上角的＋同一列（CHANGE_15 §1），搜尋列在標題下方，搜尋直接列結果。
- 第 2 層分類清單：排序（4 種，記住）與篩選（主／單／爆）popover；左滑封存、長按合併／封存／刪除。
- 動作詳情（`Views/Detail/`）：數據／說明／歷史；⋯「編輯動作」、說明分頁「編輯說明」；個人紀錄和歷史的列 → 推入訓練摘要頁（CHANGE_14 §4）；折線圖是強調色，點一下浮出數字、那一點放大（CHANGE_11 §5 拿掉「打開這次訓練」）。

**2-10. 設定**（`Views/Settings/`）
- CHANGE_13 §1 起是「今天」右上角齒輪打開的 sheet（自己的 NavigationStack、右上角系統的關閉按鈕，CHANGE_15 §1 起和大字的標題同一列；導覽路徑在 `WorkoutCoordinator`，換主題時停在原頁）。
- 5 列：外觀（主題）、單位與進位、訓練（每週目標 1–7 次、只有有氧的訓練也算、自動休息、即時動態）、備份與還原（匯出、匯入、自動備份清單；CHANGE_11 起備份包含設定）、關於（版本、簽署到期）。

**2-11. 小工具與系統畫面**（`Shared/LastWorkoutViews.swift`、`LiftLogWidgets/`）
- 小型小工具：右上角＋（建立菜單，訓練中隱藏）；點其他地方 → 訓練中打開訓練，否則回到今天。
- 鎖定畫面三種：不放按鈕，點擊導向同上。控制項、App Shortcut 不變（開始訓練走同一個入口）。
- 即時動態（`Shared/WorkoutActivityViews.swift`）：鎖定畫面休息和非休息一樣高（150 pt，上限 160），每列固定高度、文字一行截斷、字級最大到 large；動態島展開同樣的層級（約 140 pt），左上角是日型簡稱（「DE 上肢」，沒有日型「訓練」，CHANGE_11 §6），經過時間一定完整（放不下時系統移到下一行）。

---

## 3. 導覽地圖
```
LiftLogApp → RootView（TabView，固定深色）
├─ [今天] TodayView（NavigationStack，系統大標題）
│   ├─ 右上角齒輪 → sheet 設定 SettingsView ─ push → 外觀／單位與進位／訓練／備份與還原／關於
│   ├─「下一次」卡 → sheet 建立菜單 PlanSheet（一個畫面：點一格 → Menu 換候選；「開始訓練」→ 訓練中）；訓練中時 → 訓練中畫面
│   └─「本週」卡 → sheet 訓練狀態（只顯示資訊）
├─ [歷程] HistoryView（NavigationStack，路徑在 WorkoutCoordinator.historyPath）
│   ├─ 紀錄 ─ push → 訓練摘要頁（⋯ 編輯 → 全螢幕 SessionEditorView）
│   ├─ 統計 → 主項 ─ push → 動作詳情 ─ push → 訓練摘要頁；體重卡 → sheet 記錄體重 → sheet 從健康 App 帶入
│   └─ ⋯ 補登訓練 → sheet 建立菜單 PlanSheet（最上面是日期和時間）→「補登這次訓練」或自由選動作 → 推入訓練摘要頁 → 編輯（全螢幕）
├─ [動作庫] LibraryView（NavigationStack）
│   ├─ 分類 ─ push → 分類清單（排序／篩選 popover）─ push → 動作詳情 ─ push → 訓練摘要頁
│   ├─ 已封存 ─ push → 已封存清單
│   ├─ 搜尋結果 ─ push → 動作詳情
│   └─ ＋ → sheet 新增動作；長按 → sheet 合併到…
├─ 分頁列的附屬列：訓練中橫條 → 訓練中
└─ sheet（全高，往下拖＝收合）：訓練中 WorkoutView（或完成後的 WorkoutSummaryView，不能往下拖）
    ├─ sheet → 新增動作、換動作、從 Apple Watch 帶入、動作說明（唯讀）
    └─ 完成 → 確認 → 完成畫面（新紀錄、今天體重）→「完成」關閉

開始訓練：只經過 WorkoutLauncher（下一次卡、自由選動作、再做一次、補登、liftlog://new、控制項、Siri、小工具＋）
深層連結 liftlog://（onOpenURL、intent、App Group 裡的待處理連結 → DeepLinkRouter → RootView；設定開著時先關掉）
├─ new：建立菜單（有進行中的訓練時先問）
├─ workout：打開進行中的訓練；沒有就等於 today
└─ today：切到今天分頁
```

---

## 4. 架構

### 4-1. 目錄結構（行數）
```
LiftLog/                     App target
  LiftLogApp.swift           進入點                                              18
  Models/   Models.swift、Enums.swift                                         381
  Logic/    32 檔：建立菜單（PlanBuilder、一個畫面的狀態 PlanMenu）、角色、訓練操作、新紀錄（NewRecords）、統計快取與重算時機、App 的「現在」、資料遷移、體重、時間編輯、部位與訓練頻率、訓練次數與每週目標、訓練狀態、今天的兩張卡和點點日曆（TodayCards）、平衡卡的內容等  3,790
  Data/     Backup.swift（備份、seed 匯入、動作庫補充、說明匯入）、SettingsSnapshot.swift（備份裡的設定）、seed.json、ExerciseGuides.json  564＋JSON
  Theme/    Components.swift（共用元件、Metrics、按鈕和按壓樣式）、KeyboardDismiss.swift（收起鍵盤）、
            ChartSelection.swift（圖表的選取手勢和顏色 ChartEmphasis）、RegionStyle.swift（部位顏色、斜紋、圖例、部位的字、標籤）  565
  Intents/  intent 的 perform、App Shortcut                                     70
  Views/    RootView 300、Today 369、History 1,270、Plan 312、Workout 1,515、Library 583、
            Detail 627、Settings 510、Log 100、Debug 534（只在 DEBUG，含真實資料驗證）
Shared/     App 和小工具共用：主題（含共用的部位色 BodyPart）、日型、部位、快照、深層連結、待處理連結、RelativeDay、即時動態、intent  946
LiftLogWidgets/  小工具 target：小工具、即時動態、控制項                           156
LiftLogTests/    40 檔，Swift Testing                                         4,673
LiftLogUITests/  16 檔＋共用，XCUITest（CHANGE_10）                             1,267
tools/      parse_log.py、migration_review.py、pixel_compare.swift、unused_scan.py（沒有引用的程式）、verify_real_data.py（真實資料驗算）、
            icon 產生器、截圖（screens/final、change08～change15）；fixtures/（真實備份和驗證輸出，在 .gitignore，不 commit）
```

### 4-2. 資料模型（SwiftData，`LiftLog4.store`，沒有改結構以外的東西）
- **Exercise**：id、name、category、tags、aliases、englishName、equipment、logType、note、isArchived、restSeconds、meRotation／deRotation、說明欄位、myNotes → sessionItems。
- **WorkoutSession**：id、startedAt、endedAt、title、**isTitleCustom（CHANGE_07，預設 false）**、note、hasTime、dayType、region、modeID → items。
- **SessionExercise**：id、session、exercise、order、note、role → sets。
- **SetRecord**：id、order、kind、weightKg、reps、incline、speed、minutes、seconds、isCompleted、completedAt、healthWorkoutID。
- **BodyWeight**：date、kg（CHANGE_07 有畫面了，同一天一筆）。
- **其他持久化**：
  - UserDefaults：`theme.id`、`weightUnit`、`autoRestTimer`、`liveActivity.enabled`、`round.*`、`restTimer.*`、`library.sort`、`history.segment`、`history.frequencyPeriod`、`weeklyGoal.goal`、`weeklyGoal.cardioOnlyCounts`。設定頁的這些值（不含畫面的記憶和休息計時的狀態）CHANGE_11 起也寫進備份。
  - 一次性旗標：`libraryAdditions.v1/v2`、`conjugateLibrary.v1`、`guidesImported.v2`、`migration.assistToNegative`、`migration.autoTitles`。
  - Documents/AutoBackups：遷移前的自動備份。
  - App Group：小工具快照 `widgetSnapshot.v1`、小工具＋的待處理連結 `pendingDeepLink`。
- **備份 JSON**：version 7（CHANGE_11 §8 加了選填的 `settings`），`migrations` 是已經套用的遷移；可以讀 v2（seed）～v6，舊檔沒有設定時設定不變。匯入後補做檔案裡沒套用的遷移，沒有這個欄位的視為都沒套用。

### 4-3. 服務與狀態
- `LiftLogStore.container`：唯一的 ModelContainer，畫面和 intent 共用 mainContext。
- `WorkoutLauncher`（@Observable，environment）：開始訓練的唯一入口，管建立菜單的 sheet、繼續／新菜單的問題、結束舊訓練的確認、補登、再做一次。
- `WorkoutCoordinator`（@Observable）：目前分頁、全螢幕或縮小、完成摘要、歷程的導覽路徑（CHANGE_14 §4：補登時切到歷程推入摘要頁；以前是摘要浮窗要開哪一次）、訓練狀態浮窗、設定的 sheet 和它的導覽路徑（CHANGE_13 §1；「今天」的導覽路徑隨分類待練清單刪掉）。
- `StatsCache.shared`（@Observable）：今天、動作庫、統計要用的數字（CHANGE_08 加上每天的部位與名稱、訓練頻率的週和月；CHANGE_09 加上算進次數的日子、每週天數、每週目標的預設值；CHANGE_10 加上訓練狀態；CHANGE_13 加上「下一次」卡的主項和它的紀錄、每天的部位 `dayRegions`、每個分類最近一次完成組和本週卡的提醒，刪掉日曆的 `DayStat` 和動作庫的「最久沒練」；CHANGE_14 的點點日曆和平衡卡的空狀態也讀快照）；存檔後 0.3 秒重算，「只有有氧的訓練也算」改變時也重算；CHANGE_11 起日期改變時也重算（回到前景而且換了一天、跨過午夜、時區或系統時間改變，規則在 `StatsRefresh`），快照記下計算時的「現在」，主項進步卡用全 App 唯一的估算 1RM。
- `TrainingCount`／`WeeklyGoal`（`Logic/WeeklyGoal.swift`，CHANGE_09）：全 App 唯一的訓練次數規則（週一開始、以天為單位、只算有完成組的已結束訓練、只有有氧的處理）和每週目標（預設值；CHANGE_10 拿掉了達標和連續週數）。`TrainingStatus`（`Logic/TrainingStatus.swift`，CHANGE_10）：訓練狀態浮窗的本週、上週同期、輪替，全部呼叫共用函式。
- `DataMigrations`／`AutoBackup`：啟動時的遷移與遷移前備份；`DataMigrations.restore` 是匯入和還原的唯一入口（還原後補做沒套用的遷移）。
- `RestTimer.shared`、`WorkoutService.shared`、`WorkoutActions`、`DeepLinkRouter.shared`、`SnapshotWriter.shared`、`LiveActivityController.shared`：同 CHANGE_06。
- 純邏輯（可單元測試）：PlanBuilder、PlanMenu（CHANGE_15：建立菜單一個畫面的狀態）、NewRecords（CHANGE_15：新紀錄）、Roles、SetLogic（含 SessionTitle）、SessionTimeEdit、BodyWeightLog、RelativeDay、ExerciseStats、Recency、LibrarySort、StatsRefresh、AppClock、SettingsSnapshot、DayRegion、TrainingFrequency、TrainingCount、WeeklyGoal、TrainingStatus、NextCard／WeekCard（CHANGE_13；CHANGE_14 起 WeekCard 含點點日曆）、BalanceCardContent（CHANGE_14）、IntensityTable、ProvisioningProfile。

### 4-4. 共用元件
- `Theme/Components.swift`：`.card()`、ThinBar、Chip、AccentChip（CHANGE_15 從建立菜單搬過來）、`Metrics`、PrimaryButton／PrimaryButtonLabel、FilterCapsule、ElapsedTimeText（CHANGE_12 起是系統的計時文字）、`.pressable`（小按鈕）、`TapSurfaceStyle`（`.tapCard`／`.tapRow`／`.tapListRow`）和 `TapListRow`（CHANGE_10：可以點的卡片和列）。`.hidesTabBarOnScroll()` 在 CHANGE_11 刪掉（分頁列交給系統）；`ScreenHeader` 在 CHANGE_13 刪掉（「今天」改用系統的大標題）。
- `Theme/KeyboardDismiss.swift`：`dismissKeyboard()`、`KeyboardDismissOnTap`（點空白處收起鍵盤）。`Theme/ChartSelection.swift`：`chartDateSelection`、`PressThenDragGesture`（圖表的選取）、`ChartEmphasis`（CHANGE_14：單一數列的強調色、長條選取時其他變淡、選到的點放大）。`Text.warning`、`Staleness.text`（CHANGE_14：warning 色前面加圖示）。
- `Theme/RegionStyle.swift`：`DayRegion.fill／barFill`（CHANGE_14 起用共用的系統色 `BodyPart`，`DayRegion.swatch`；全身的斜紋 `RegionStripes` 依環境解析）、RegionLetter（「不以顏色區分」時的下、上、全）、RegionLegend（長條或日曆格子）、PeekLabel（圖表共用）。
- `Shared/RelativeDay.swift`：今天／昨天／N 天前（App 和小工具共用）。
- 共用畫面：`WorkoutSummaryPage`（CHANGE_14 §4，取代 `WorkoutSummarySheet`）、`SessionTitleField`、`ExerciseInfoSheet`、`LibraryExerciseRow`、`TrainingStatusSheet`。`TrainingCalendar` 在 CHANGE_13 刪掉（CHANGE_14 的點點日曆是本週卡裡新寫的 `WeekCalendar`）。
- 上一版列出的重複（大膠囊按鈕 4 種高度、3 種篩選膠囊、3 份經過時間、4 處天數格式、2 份衝突對話框）都已合併。

---

## 5. 品質狀況

### 5-1. 建置
- Debug（含測試）、Release（模擬器）、Release（iphoneos，不簽署）的 clean build：**0 個 warning、0 個 error**。

### 5-2. 測試
- **302 個全部通過，0 失敗**：單元測試 261（40 檔）、UI 測試 41（16 檔＋共用），iPhone 17 Pro 模擬器，`-parallel-testing-enabled NO`。
- CHANGE_15 新增：PlanMenuTests 4（照建議開始和舊的兩步建立的訓練完全相同：四個日型 × 1／2／3 × 跑步機；改日型全部重算、改動作數和跑步機保留換過的格子；換主項重建拉／推；候選的小字和處方一行）、NewRecordsTests 7（高於之前最好的才算、相等不算、以前沒有不算、熱身和超過 10 下不算、好幾個動作全部列出、只有重量型、只和之前的訓練比）、SessionTimeEditTests（補登的預設時間）、WorkoutLauncherTests（從建立菜單的畫面補登）；UI 測試 TitleBarUITests 4（四個第 1 層的標題和按鈕同一列、捲動後回到原位）、PlanSheetUITests 4（兩下開始、換一格只換那一格、換日型、補登用同一個畫面）、WorkoutSheetUITests 2（往下拖縮小到橫條、完成畫面拖不掉）、NewRecordUITests（完成畫面的新紀錄區塊、摘要頁的獎盃）。刪掉舊的新紀錄測試 3 個（SetLogicTests 2、LogTypeAndUnitTests 1）；PlanTests 的預覽測試改名。
- CHANGE_14 新增：TodayCardsTests 的點點日曆 6 個（欄數依寬度且至少 12 週、最右邊一欄是本週、今天和之後的外框、月份標在第一個週一、跨月跨年、每一格和 dayRegions 一致；取代 7 個圓點的 2 個）、ThemeTests（部位色是共用的系統色、六個主題相同、色相差 60 度、對比度 3:1；取代和強調色差 40 度的測試）、ChartEmphasisTests 2（單一數列用強調色、長條選取時其他變淡、恢復）、BalanceCardTests 2（還沒有紀錄、0 沒練）；UI 測試 SummaryPageUITests 3（紀錄推入摘要頁和返回、編輯和刪除、動作詳情的歷史推入同一頁）、TrainingStatusUITests 改成輪替列點了沒有反應、ChartSelectionUITests 的有氧選取 2 秒後恢復。WorkoutLauncherTests、SessionTimeEditTests、TrainingCountTests 跟著改。
- CHANGE_13 新增：TodayCardsTests 10（「下一次」卡沒有訓練／有進行中的訓練、DE／ME／沒有主項的寫法、快照的主項和紀錄；本週圓點依部位、只有有氧是中性灰、今天、週一和週日的邊界；輪替膠囊四種「下一次」；提醒 14／15 天、取最多、不列核心補強有氧和沒練過的、快照用分類最近一次完成組）、ThemeTests（部位色和 accent、warning 至少 40 度；次要文字對比度 4.5:1，取代原本的上肢色測試）；UI 測試 SettingsSheetUITests（齒輪打開設定、第 2 層、關閉）、TodayLayoutUITests 改成沒有訓練和有訓練兩個。刪掉 ActivityCalendarTests 2 個；TrainingStatusUITests、TabBarMinimizeUITests、StatsScrollUITests、StatsRefreshTests 跟著改。
- CHANGE_12 新增：UI 測試 TimerTextUITests 3（經過時間「1:05:30」和「24:30」的格式，訓練畫面和附屬列都看；「+15」「-15」「跳過」後休息倒數立刻更新）、WorkoutBarUITests（點附屬列的橫條打開訓練畫面、收合回到橫條）、TodayLayoutUITests（今天一個畫面放得下，量近 30 天卡片和分頁列的空隙）。RestTimerTests 改成直接用結束時間算。
- CHANGE_11：新增 StatsRefreshTests 3（跨日重算、週日到週一、`-fakeNow`）、IslandTitleTests 3、BackupTests 3（設定來回還原、自動的每週目標、舊格式）、StatsCacheTests（全 App 一種估算 1RM）；UI 測試 TabBarMinimizeUITests 2、KeyboardUITests（訓練畫面點空白處）、DetailChartUITests、TrainingStatusUITests 2（高度、最大字級）、DynamicIslandUITests（日型簡稱）。刪掉分頁列收起邏輯的測試（單元 18、UI 8）和隨舊程式刪掉的測試；候選列的測試（單元 8、UI 2）在 `c0ac0e7` 通過，候選列拿掉後一起刪掉。真實資料的統計比對用 `tools/verify_real_data.py`（不是 Xcode 測試，資料不進 repo）。
- CHANGE_10 新增：UI 測試 target `LiftLogUITests`（統計頁從圖表往上捲、圖表點選、各分頁收起分頁列、訓練中橫條、捨棄訓練、鍵盤收合、模擬器上的動態島、訓練狀態）；單元測試 TrainingStatusTests 6（上週同期的範圍、本週組數、輪替和建立菜單一致、14 天警示）、PlanTests（DE 建議重量＝換算表 60%）、WorkoutActionsTests（上一次同角色優先、捨棄要確認）、TabBarAutoHideTests 3（短頁面、切換後的跳動、稀疏的位置）、ThemeTests（按壓色）。拿掉連續達標 5 個、日曆標籤 2 個。
- CHANGE_09 新增：TrainingCountTests 10（以天為單位、只算已結束而且有完成組、只有有氧的開關、週一開始、跨年那一週、連續達標 4 種情況、改目標後重新判斷）、WeeklyGoalTests 5（預設值有紀錄和沒紀錄、改過之後不再自動計算）、WorkoutActionsTests（「繼續編輯」不改資料）、TrainingRegionTests（平均排除本週和本月）、TabBarAutoHideTests 3（橫條消失後留白變小、分頁列切換留白不變）。
- CHANGE_08 新增：WorkoutActionsTests（T1 編輯時沒打勾的組）、TabBarAutoHideTests（T2 底部回彈序列、80 pt、連續 24 pt、頂端回彈）、TrainingRegionTests（T3 週和月、部位、平均、只算已結束；部位合併）、ActivityCalendarTests（T4 格子對日期、標籤文字）、ThemeTests（upperBody 的色相和亮度）、WidgetSnapshotTests（即時動態高度）。
- CHANGE_07 新增或改寫：DataMigrationsTests 6、WorkoutLauncherTests 6、StatsCacheTests 3、SessionTitleTests 6、SessionTimeEditTests 4、BodyWeightLogTests 6、DeepLinkTests 9、WorkoutActionsTests（上一次只取之前的訓練）、LibraryTests、ExerciseListsTests、FilterTests、RestTimerTests（改用隔離的設定和安靜的通知）。
- 畫面用 DEBUG 啟動參數配合 `simctl io screenshot` 驗證（`tools/screens/final/`、`change08/`、`change09/`、`change10/`），需要手勢的畫面用 UI 測試的截圖；歷程捲到底部的穩定性用 `tools/pixel_compare.swift` 比對連拍的像素。

### 5-3. 上一版的問題現在的狀態
**已修（CHANGE_15）**
- 三個分頁的第 1 層標題自己一列，上面空一列只放按鈕 → 標題和按鈕同一列，首頁多出 52 pt。
- 建立菜單要經過三個問題、「下一步」、選動作才能開始 → 一個畫面，「開始」→「開始訓練」兩下。
- 補登要先選時間、再選照建議或自由選 → 和建立菜單同一個畫面。
- 訓練畫面只能按左上角收合 → 往下拖也能收合；完成畫面不會被誤拖掉。
- 新紀錄只看最重的一組（多做幾下不算進步）→ 估算 1RM，一個共用函式；完成畫面最上方顯示新舊數字。

**已修（CHANGE_14）**
- 首頁拿掉日曆後看不到更早的訓練分佈 → 點點日曆回到本週卡，最右邊一欄就是本週。
- 每個主題各自的部位色（例如洋紫、天藍）不直覺，增加對比也不會變 → 系統藍和系統橘，六個主題共用。
- 圖表全部是灰色 → 單一數列用強調色。
- 「N 天前」超過 60 天、簽署快到期等只靠 warning 色 → 都加上圖示。
- 訓練摘要是半高的浮窗，內容多時要再拉高 → 推入的全高頁面，可以滑動返回。
- 剛裝好沒有紀錄時，平衡卡一整排黃色的「0 沒練」→ 「還沒有紀錄」。

**已修（CHANGE_13）**
- 「今天」的系統大標題放不下（CHANGE_12 §3）→ 首頁只剩兩張卡，大標題放得下，`ScreenHeader` 刪掉。
- 有進行中的訓練時附屬列蓋住近 30 天最後一列（CHANGE_12 報告第 4 節）→ 近 30 天卡搬到平衡卡，首頁兩張卡在附屬列上方。
- 換主題時設定跳回第 1 層（換主題重建整個畫面）→ 設定是 sheet，換主題時停在「外觀」。
- 石墨藍的上肢色（橘）和 warning 很像；下肢用 accent，和「今天」「下一次」的強調色混在一起 → 每個主題有自己的兩個部位色。
- 綠黃紅表示好壞（近 30 天、N 天前、主項進步、換算表、推拉比、新紀錄）→ 中性色＋文字，warning 只用在提醒。
- 訓練畫面的自動名稱是灰色粗體，看起來像停用 → 主要文字色。

**已修（CHANGE_12）**
- 經過時間和休息倒數用 TimelineView 每秒（0.5 秒）整塊重畫 → 系統的計時文字自己跳秒。

**已修（CHANGE_11）**
- 過了午夜沒有存檔時「本週」「N 天前」是舊的 → 日期改變時重算統計快照。
- 每週目標和其他設定沒有進備份 → 備份 version 7 包含設定，還原時一併還原。
- 4 個分頁各有一個訓練中橫條（各自 @Query 和每秒更新）→ 系統的附屬列只有一個。
- 沒有人用的舊程式（`MaxEffortRecords`、`MainLiftSummary`、`Exercise.homeSummary`、`ActivityCalendar.dailyCounts`／`level`、`SetLogic.finish` 等）→ 刪掉（清單在報告第 3 節）。
- 主項進步卡和換算表各算一次估算 1RM → 同一個函式。

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
- 開發用的 `-emptyData` 之後再用 `-demoData`，動作沒有輪替順序（一次性旗標還在，只影響 DEBUG；CHANGE_11 報告第 7 節）。
- 深層連結開建立菜單時，如果全螢幕畫面開著，仍用固定 600 ms 等它關掉。
- 多處 `try? context.save()` 吞掉錯誤。
- 過大的檔案：`Backup.swift` 493、`PlanBuilder.swift` 440、`WorkoutEditor.swift` 435 行。

### 5-4. 要在實機確認的事
- `tools/CHANGE_15_REPORT.md` 第 7 節：標題列的樣子、建立菜單的操作手感（換日型、換候選的 Menu、動作數和跑步機）、往下拖縮小的手感、各種觸覺的強弱、新紀錄的動畫。
- `tools/CHANGE_14_REPORT.md` 第 8 節：橘藍在健身房的燈光下好不好分辨、日曆格子的大小好不好讀、推入頁面和滑動返回的手感、圖表的顏色會不會太搶眼，以及 warning 的圖示、刪除後返回、補登的流程。
- `tools/CHANGE_13_REPORT.md` 第 7 節：齒輪按鈕的位置和手感、首頁兩張卡的感覺、顏色在實際光線下是否好分辨（部位色、強調色、warning；不以顏色區分）、改成中性色的圖表、訓練畫面的名稱顏色、平衡卡、動作庫第 1 層、設定開著時的小工具和控制項。
- `tools/CHANGE_12_REPORT.md` 第 5 節：計時跳秒是否順暢（訓練畫面、附屬列、休息倒數）、「+15」「-15」「跳過」、系統進度條的樣子、耗電、附屬列打開和收合。
- `tools/CHANGE_11_REPORT.md` 第 8 節：分頁列縮小和恢復的手感、附屬列的互動、跨午夜重算（隔天打開）、訓練畫面點空白處收鍵盤、輔助引體向上的負號鍵盤、動態島的日型簡稱、訓練狀態浮窗的高度、圖表的 2 秒、備份的設定、主項進步卡的數字。
- `tools/CHANGE_10_REPORT.md` 第 5 節：從圖表位置往上滑（包括平衡卡）、各分頁收起分頁列、點空白處和捲動收起鍵盤、按壓回饋、訓練狀態浮窗的拖曳、實機的動態島。
- `tools/CHANGE_09_REPORT.md` 第 4 節：每週目標的數字、達標小點、訓練頻率的目標線、「只有有氧的訓練也算」、訓練中橫條出現和消失時的底部留白、編輯畫面的「繼續編輯」。
- `tools/CHANGE_08_REPORT.md` 第 5 節：歷程捲到底部的手感、日曆拖曳的觸覺回饋、鎖定畫面休息狀態、動態島、鍵盤的「完成」。
- `tools/CHANGE_07_REPORT.md` 第 4 節：小工具＋、HealthKit 體重權限、真實資料的遷移結果、sheet 的手感。

---

## 6. 畫面截圖
- `tools/screens/change15/`：CHANGE_15 的驗收截圖（V1 四個第 1 層的標題列、V2 首頁兩種狀態、V3 建立菜單四個日型、V4 候選的 Menu、V5 補登用的建立菜單、V6 訓練畫面往下拖到一半（錄影的格）、V7 完成畫面的新紀錄和摘要頁的獎盃、歷程穩定性連拍、空資料）。索引在 CHANGE_15 報告第 8 節。都是乾淨安裝＋示範資料，沒有真實資料。
- `tools/screens/change14/`：CHANGE_14 的驗收截圖（V1 首頁的點點日曆、V2 有進行中的訓練、V3 六個主題的首頁、V4 歷程統計的圖表和有氧選取時變淡、V5 動作詳情的折線圖選取、V6 訓練摘要頁最上面和最底、V7 空資料的平衡卡、V8 不以顏色區分、歷程穩定性連拍、空資料的首頁和動作庫）。索引在 CHANGE_14 報告第 9 節。都是乾淨安裝＋示範資料，沒有真實資料。
- `tools/screens/change13/`：CHANGE_13 的驗收截圖（V1 首頁、V2 有進行中的訓練、V3 本週卡的提醒、V4 設定的 sheet 兩層、V5 平衡卡（含 0 沒練）和訓練頻率、S5 訓練狀態、V6 動作庫第 1 層、V7 不以顏色區分（首頁、訓練頻率圖例）、V8 六個主題的首頁、歷程穩定性連拍、空資料的首頁、統計、動作庫）。索引在 CHANGE_13 報告第 8 節。都是乾淨安裝＋示範資料，沒有真實資料。
- `tools/screens/change12/`：CHANGE_12 的驗收截圖（V1 今天和大標題放不下的那一張、V2 放大轉場找不到附屬列的來源（錄影的格）和對照組、收合後回到附屬列、G2 的經過時間和休息倒數、歷程穩定性連拍、空資料）。索引在 CHANGE_12 報告第 6 節。都是乾淨安裝＋示範資料。
- `tools/screens/change11/`：CHANGE_11 的驗收截圖（V1 分頁列展開和縮小、V2 訓練狀態（一般和最大字級）、V3 模擬器上的動態島「DE 上肢」、V4 鍵盤和候選列融不進鍵盤的五張、V5 動作詳情的折線圖、歷程穩定性連拍、空資料）。索引在 CHANGE_11 報告第 9 節。都是乾淨安裝＋示範資料，沒有真實資料。
- `tools/screens/change10/`：CHANGE_10 的驗收截圖（V1 首頁、V2 訓練狀態（含空資料）、V3 數字鍵盤、V4 捨棄訓練、V5 DE 主項、V6 動態島（預覽和模擬器上真的動態島）、V7 連拍比對、V8 沒有「›」）。索引在 CHANGE_10 報告第 6 節。
- `tools/screens/change09/`：CHANGE_09 的驗收截圖（V1 首頁、V2 設定、V3 訓練頻率、V4 詢問、歷程穩定性的連拍和比對結果、空資料）。索引在 CHANGE_09 報告第 5 節。
- `tools/screens/change08/`：CHANGE_08 的驗收截圖（V1 每個畫面 5 張連拍和比對結果 `V1_pixel_compare.txt`）。索引在 CHANGE_08 報告第 6 節。
- `tools/screens/final/`：CHANGE_07 的驗收截圖（iPhone 17 Pro 模擬器，seed＋示範訓練；V7 是空資料）。索引在報告第 5 節；今天的日曆和訓練頻率卡已經換成 CHANGE_08 的樣子。
- `tools/widget_previews/`：CHANGE_05 的小工具與即時動態預覽（小型小工具還沒有＋，新的見 `screens/final/V6_widget_small.png`）。
- `tools/theme_previews/`：舊的 5 個主題，已過期。
- `tools/icon_concepts/`：icon 候選。
- 截圖方式：DEBUG 啟動參數（列在 SPEC.md「13. 開發用啟動參數」）配合 `xcrun simctl io <裝置> screenshot`。
