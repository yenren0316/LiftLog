# LiftLog：給 Claude 的專案規則

個人用的 iOS 健身紀錄 App（SwiftUI＋SwiftData，iOS 26，用免費 Apple ID 簽署安裝）。使用者用繁體中文溝通，回覆也用繁體中文。
- 規格以 `SPEC.md` 為準；現況、進度、已知問題在 `tools/STATUS.md`。
- 每一輪需求的原文在 `tools/changes/`，實作結果在 `tools/CHANGE_NN_REPORT.md`。

## 執行規則（CHANGE_07 規則 1–7，之後每一輪都適用）

1. 每個階段（或每一節）完成，而且編譯成功、全部測試通過後，就 commit 一次。全部完成之後，再推上 GitHub。
2. 遇到規格沒寫清楚的地方：選擇最不會破壞資料、也最符合設計原則的做法，記到最終報告的「自行決定」裡，然後繼續。
3. 某個條件連續修 3 次還是過不了：把那個子功能恢復成修改前的狀態，記到「未解決」，然後繼續。不能 commit 測試失敗的程式碼。
4. 測試一律用 iPhone 17 Pro 模擬器，並加上 `-parallel-testing-enabled NO`。
5. 截圖驗證要用接近實際的資料：載入 seed，加上幾筆示範訓練。另外也要用一份空資料跑一次，檢查空狀態。
6. 任何資料遷移執行前，App 都要先在 Documents 裡自動寫一份備份 JSON，檔名包含日期和遷移名稱。「設定 → 備份與還原」要列出這些自動備份，可以匯出，也可以還原。
7. 從 JSON 匯入或還原備份時，備份產生時還沒套用的遷移要再跑一次，不受「只執行一次」的標記影響。依備份檔的 `migrations` 欄位判斷，沒有這個欄位的視為都沒套用。

另外每一輪都照做：
- 一次做完，中途不停下來等確認。
- 依每一輪的「收斂標準」自行驗證。
- 完成後產出報告，更新 `SPEC.md` 和 `tools/STATUS.md`。
- 推上 GitHub，告訴使用者報告的位置。
- 最後更新簽署並安裝到 iPhone（見「每一份 CHANGE 的最後一步」，CHANGE_12 起）。

## 設計原則（CHANGE_07）

- 三個分頁（`AppTab`）各只回答一個問題（CHANGE_13 §1 起設定不是分頁）：
  - 今天：下一次該練什麼？
  - 歷程：我練了什麼、進步了多少？
  - 動作庫：我有哪些動作？
  - 設定（「今天」右上角齒輪打開的 sheet）：App 怎麼運作？
- 最多三層：第 1 層是分頁，第 2 層是清單或摘要，第 3 層是詳情或編輯。第 3 層不再 push，連到其他內容一律用唯讀浮窗。
  - 例外（CHANGE_14 §4）：訓練摘要是推入的頁面（`WorkoutSummaryPage`），從歷程的紀錄、動作詳情的歷史和個人紀錄在各自的 NavigationStack 推入；摘要頁本身不再往下推。
- 開始新訓練只走 `WorkoutLauncher`（主要入口是「今天」的「下一次」卡）。建立菜單是一個畫面（`PlanSheet`，CHANGE_15 §2），補登也用它。
- 第 1 層（今天、歷程、動作庫、設定的 sheet）的標題用 `.toolbarTitleDisplayMode(.inlineLarge)`，大字的標題和右上角的按鈕同一列；第 2 層以下用 `.inline`（CHANGE_15 §1）。
- 訓練畫面是全高的 sheet：往下拖＝收合到「訓練中」橫條，完成畫面 `.interactiveDismissDisabled`（CHANGE_15 §3）。

## 建置與測試

- `xcode-select` 指向 CommandLineTools，所有 `xcodebuild`／`xcrun` 前面加 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。
- 模擬器用 iPhone 17 Pro（`9113BC81-BD51-4BD6-8AF8-DC293FB12F23`）。iPhone 17 那台存著使用者的示範資料，而且常卡住，不要用。
- 全部測試：
  ```
  xcodebuild -project LiftLog.xcodeproj -scheme LiftLog -destination 'id=9113BC81-BD51-4BD6-8AF8-DC293FB12F23' \
    -derivedDataPath build -parallel-testing-enabled NO test
  ```
  - scheme 的 Test 包含單元測試 `LiftLogTests`（Swift Testing）和 UI 測試 `LiftLogUITests`（XCUITest）。
  - 只跑單元測試加 `-only-testing:LiftLogTests`。
  - 結果用 `xcrun xcresulttool get test-results summary --path <xcresult>` 讀。
  - 「test runner hung before establishing connection」是環境問題，換模擬器或重開模擬器，不要一直重試。
  - 測試跑完模擬器會關掉，要安裝 App 前先 `simctl boot`。
- 收斂標準 G1：以下三種 clean build 都要 0 error、0 warning（`grep -c 'warning:'` 計數）：
  - Debug（含測試 target，`build-for-testing`）
  - Release 模擬器（`-destination 'generic/platform=iOS Simulator'`）
  - Release 實機（`-destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`）
- 沒有 Simulator.app 的 GUI，`simctl` 不能點畫面。
  - 需要手勢的驗證（捲動、點選、拖曳、鍵盤、動態島）寫成 UI 測試。截圖用 `XCTAttachment`，再用 `xcrun xcresulttool export attachments` 取出。
  - 模擬器偶爾漏掉手勢：先等畫面穩定再操作，每一步最多重試一次；一直失敗的照樣讓測試失敗。
  - 需要示範訓練的 UI 測試用 `launchWithoutActiveWorkout`，先清掉上次留下的進行中訓練。
- UI 測試裡的 `print` 看不到，診斷資訊寫進斷言的訊息，或附截圖。
- 捲動相關的行為用 DEBUG 紀錄查：`-tabBarLog YES`，再用 `xcrun simctl spawn <裝置> log show --predicate 'subsystem == "com.aaronhou.LiftLog"'` 讀。

## 截圖

- 存到 `tools/screens/changeNN/`。
  - 檔名用收斂標準的編號開頭：`V1_today.png`、`V2_…`。
  - 空資料用 `E_…`。
  - 歷程穩定性的連拍用 `stability_<畫面>_1～5.png`，比對結果寫進 `stability_pixel_compare.txt`。
- 最後的截圖要乾淨安裝：`simctl uninstall` 後安裝，啟動一次 `-demoData YES`。空資料用 `-emptyData YES`，放在最後，因為它會清空資料。
- 截圖：`xcrun simctl io <裝置> screenshot <檔案>`，配合 DEBUG 啟動參數打開要截的畫面。
- 歷程穩定性（CHANGE_08 V1，每輪重跑）：
  - 範圍：紀錄、統計、動作庫第 1 層、分類清單（`-libraryCategory core`）四組。
  - 方法：用 `-scrollToBottom <紀錄|統計|動作庫|分類>` 捲到底部，每 0.5 秒連拍 5 張。
  - 比對：`swift tools/pixel_compare.swift --mask-top 200 <5 張>`，要「全部相同」。
- 逐張看過截圖：檢查沒有不該有的截斷、沒有重疊、顏色都來自主題 token、首頁一個畫面放得下。

## 報告（`tools/CHANGE_NN_REPORT.md`）

- 開頭：日期、範圍、驗證環境、更新了哪些文件。
- 各節：
  - 每一條收斂標準的結果：通過或未通過、驗證方式。測試對應到規格要求的每一項。
  - 規格要求查的原因：怎麼查、查到什麼。
  - 自行決定的事項：編號、分節。
  - 未解決的事項：要寫「有沒有觸發規則 3」。
  - 實機確認清單。
  - 截圖索引：檔名、內容、對應的標準。
  - commit 列表。
- 推翻以前報告的某一條時，在舊報告那一條旁邊加粗體註記。
- `SPEC.md`：
  - 開頭加一行這一輪的摘要。
  - 修改處標出 CHANGE 和節號，例如「（CHANGE_10 §0-4）」。
  - 新的 DEBUG 參數列進「13. 開發用啟動參數」。
- `tools/STATUS.md`：更新進度表、實作和文件不一樣的地方、git log 摘要、規模和行數、測試數、已修的問題、實機確認、截圖位置。
- 寫給使用者的文字（報告、回覆）用繁體中文。

## commit 與 GitHub

- 只在使用者要求時 commit 和 push。每一輪的 CHANGE 都會要求「每一節各自 commit、最後推上 GitHub」。
- commit 訊息：
  - 英文標題，例如 `CHANGE_10 §0-4: …`，內文說明原因和做法。
  - 最後一行：`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`。
- **`LiftLog.xcodeproj/project.pbxproj` 裡使用者自己加的 `DEVELOPMENT_TEAM` 設定不 commit，一直留在工作區。** 要改 pbxproj 時的做法：
  1. 用 `git show HEAD:<path>` 拿到 commit 版本。
  2. 套用同樣的修改，`git hash-object -w` 存成 blob。
  3. `git update-index --cacheinfo` 放進 index。
  4. 工作區的檔案也套用同樣的修改。
- repo 是公開的（`yenren0316/LiftLog`）。推上去之前檢查沒有個人資訊，例如 email、名字、Team ID、本機路徑。訓練紀錄可以公開。
- tag：`before-change07`（`6f72de3`）、`v1.0-ia`（`f4ba90c`，CHANGE_07～09 收斂）、`v1.1-ia`（`e3a8a77`，CHANGE_07～15 的資訊架構與設計改版收斂，CHANGE_15 實機確認通過後）。

## 每一份 CHANGE 的最後一步：更新簽署並安裝到 iPhone

（CHANGE_12 §0 加入，照錄）

我用的是免費的開發者帳號，簽署檔只有 7 天效期，所以每次優化完順便延長。
1. 在報告寫完、推上 GitHub 之後才做。
2. 在 ~/Library/Developer/Xcode/UserData/Provisioning Profiles（舊版 Xcode 也檢查 ~/Library/MobileDevice/Provisioning Profiles）裡，用 security cms -D -i 讀出每個簽署檔的 App ID，只刪除屬於這個 App 和它的擴充（小工具、即時動態）的簽署檔。不刪其他 App 的簽署檔，也不刪憑證。
3. 用 xcodebuild 加 -allowProvisioningUpdates 重新建置 Debug 給實機，讓 Xcode 產生新的簽署檔。
4. 用 xcrun devicectl 把 App 覆蓋安裝到已連接的 iPhone（接線或同一個網路都可以）。
5. 絕對不能從手機刪除 App，也不能用任何會刪除 App 資料的安裝方式：訓練紀錄只存在手機本機。
6. 在最後回覆我的訊息裡，告訴我新簽署檔的到期日（不用寫進報告）。
7. 手機沒有連接、沒有解鎖，或安裝失敗時，跳過這一步，在最後的訊息裡提醒我自己用 Xcode 按 Run。
8. DEVELOPMENT_TEAM 等簽署設定照舊不 commit。

## DEBUG 參數

- 開發用的啟動參數（`UserDefaults.standard` 讀字面 key）一律包在 `#if DEBUG` 裡。
- 新增的參數要列進 `SPEC.md` 第 13 節，並在註解寫用途（`// 開發用：-xxx YES …`）。
- 收斂時用腳本檢查：列出所有 `UserDefaults.standard.<bool|string|integer|double|object>(forKey: "字面值")`，確認都在 `#if DEBUG` 區塊內。
- 示範與空資料：`-demoData YES`、`-emptyData YES`。各畫面的開啟參數見 SPEC.md 第 13 節。

## 程式慣例

- Swift 6，預設 MainActor。純邏輯型別標 `nonisolated`（extension 也要），放在 `LiftLog/Logic/`，寫單元測試。
- 開了 MemberImportVisibility：用到哪個框架就明確 import（`SwiftData`、`AppIntents`、`UIKit`、`CoreGraphics`、`Foundation`）。
- 註解和畫面文字用繁體中文，註解密度跟著周圍的程式碼。
- 顏色只用主題 token（`Theme.*`，定義在 `Shared/Theme.swift`）。新 token 要每個主題都有值，並加進 `ThemeTests`。
  - 每個顏色只有一個意思（CHANGE_13 §3，CHANGE_14 §2 修訂）：
    - 強調色只出現在按鈕、連結、選取的狀態、建議值、「下一次」的標記，以及單一數列的圖表（主項進步的迷你折線、體重、有氧、動作詳情的折線，用 `ChartEmphasis`）。
    - 部位色 `Theme.lowerBody`／`upperBody` 是系統藍、系統橘（`BodyPart`，六個主題共用一份，直接用系統色、不寫死色碼），只出現在資料圖形上（格子、長條、圓點、圖例）。石墨藍、石墨青的強調色和下肢相近，石墨橙的強調色和上肢相近：刻意的，靠形狀區分。
    - done 只用在完成的組；danger 是刪除和錯誤。
    - warning 只用在提醒和警示，而且每個地方都同時有圖示或文字，不只靠顏色（文字用 `Text.warning`，前面自動加 `exclamationmark.circle`）。
    - 其他資料（個人紀錄的數字、換算表、增減的正負號）、格線、座標軸和圖表上的文字用 textPrimary／textSecondary，不用綠黃紅表示好壞。今天的外框（本週卡的日曆）是主要文字色。
- 共用的做法，不要另寫一套：
  - 可以點的卡片和列：`TapSurfaceStyle`（`.tapCard`／`.tapRow`／`.tapListRow`、`TapListRow`），不用列尾的「›」。
  - 小按鈕：`.pressable`。
  - 確認：一律置中的 `.alert`，要有明確的「取消」。不用 confirmationDialog。
  - 圖表的選取：`chartDateSelection`；單一數列的顏色和長條選取時變淡：`ChartEmphasis`。
  - 分頁列：交給系統的 `.tabBarMinimizeBehavior(.onScrollDown)`，不另外處理（CHANGE_11 §1 刪掉 `.hidesTabBarOnScroll()`）。
  - 收起鍵盤：`dismissKeyboard()`、`KeyboardDismissOnTap`。不要在鍵盤上方加「完成」。
  - 訓練次數：`TrainingCount.days`；開始訓練：`WorkoutLauncher`。
  - 建立菜單：狀態在 `PlanMenu`，預設值、格子、建議、候選只用 `PlanDefaults`、`PlanRanking`、`SlotAdvice`，不另寫計算。
  - 新紀錄：`NewRecords.find`（估算 1RM 高於這次訓練之前最好的，`PersonalRecords.best1RM`）；完成畫面和摘要頁都呼叫它。
  - 觸覺：一律 `.sensoryFeedback`，強度交給系統，不直接呼叫 `UIFeedbackGenerator`（CHANGE_15 §4）。
  - 統計：存檔時在 `StatsCache` 算好，畫面只讀。
