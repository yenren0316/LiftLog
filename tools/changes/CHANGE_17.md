# CHANGE_17：鎖定畫面的按鈕仍然要求解鎖：找出根本原因並修正

## 0. 開始之前
1. 把這份 prompt 的原文存成 tools/changes/CHANGE_17.md。
2. 讀 CLAUDE.md、SPEC.md、tools/STATUS.md 和 tools/CHANGE_16_REPORT.md，了解目前的狀態。
3. CHANGE_16 還不能收斂。在 tools/STATUS.md 最上面註明：「CHANGE_16 未收斂：實機鎖定時，即時動態的『完成這組』『跳過休息』『+15 秒』都會要求解鎖」，並在 CHANGE_16_REPORT.md 第 2 節「不用解鎖」那一段旁邊加上粗體註記：「模擬器沒有設定密碼，無法驗證；實機上不成立，見 CHANGE_17」。

這次的原則：先找出原因並有證據，才修改程式。不要用猜的方式反覆修改。
CLAUDE.md 的執行規則繼續適用，但有一個例外：第 2-3 節和第 3 節的實機步驟需要我操作手機，你可以在這些地方停下來，告訴我具體要做什麼，等我回覆完成後再繼續。

## 1. 已知的事實
- 實機是有設定密碼的 iPhone，裝的是 CHANGE_16 的版本：即時動態有「完成這組」和要記錄的值（例如「32.5 kg × 3」）。
- 鎖定時按「完成這組」會要求解鎖；休息時按「跳過休息」「+15 秒」也一樣要求解鎖。所以問題不只在這次新加的按鈕。
- 手機設定：設定 → Face ID 與密碼 → 鎖定時允許取用 →「即時動態」是開的；LiftLog 沒有設定「需要 Face ID」。
- 模擬器沒有密碼，CHANGE_16 的 UI 測試無法驗證這件事。

## 2. 調查（先找原因，這一節不要修正任何行為）

### 2-1 靜態檢查
逐項檢查，每一項的結果都寫進報告的表格：
- 即時動態上的每一個按鈕：是 Button(intent:)，還是 Link 或 widgetURL？有沒有被 Link 或 widgetURL 的點擊範圍蓋住？
- 每一個 intent（完成這組、跳過休息、+15 秒）：遵循哪些 protocol（LiveActivityIntent、AppIntent、ForegroundContinuableIntent、OpenIntent 等）、openAppWhenRun、authenticationPolicy、perform 的回傳值（有沒有 opensIntent 或任何要求打開 App 的回傳）、有沒有同時編進 App 和小工具兩個 target。
- perform 裡面（包括它呼叫的所有函式）有沒有需要前景的呼叫：UIApplication 的 API、打開 URL、Activity.request 開始新的即時動態、任何需要畫面的 API。
- 實際裝到手機上的 App 和小工具擴充：用 codesign -d --entitlements 讀出 entitlements，並讀出 embedded.mobileprovision 的內容。檢查資料保護等級（com.apple.developer.default-data-protection）、App Group 和其他可能相關的項目。Info.plist 裡和即時動態、背景執行相關的設定也一起列出。
- 資料存放的位置（SwiftData 的資料庫、UserDefaults、App Group 的容器、休息倒數的狀態）和各自的檔案保護等級。

### 2-2 加上診斷紀錄（只在 DEBUG）
- 三個 intent 的 perform 在開始、成功結束、失敗時各寫一筆紀錄：時間、intent 名稱、參數、UIApplication.shared.isProtectedDataAvailable（拿得到的話）、App 目前的狀態、結果或錯誤的完整內容。
- 紀錄檔的檔案保護等級設成 .none，或放在鎖定時也能寫入的位置，確保鎖定時寫得進去。
- 設定 sheet 的最下面（只在 DEBUG）加一個「診斷紀錄」頁，列出最近 50 筆，可以清除。
- 全部包在 #if DEBUG 裡。

### 2-3 實機重現（需要我配合）
1. 把加了診斷紀錄的版本裝到手機（照 CLAUDE.md「每一份 CHANGE 的最後一步」的安裝方式，不能刪除 App）。
2. 停下來，請我做以下步驟，並告訴我每一步之後要注意看什麼：
   - 開始一筆測試用的訓練（不要用到我的真實紀錄，測完要捨棄）
   - 鎖定手機，等螢幕暗掉，按側邊按鈕讓螢幕亮起，但不要解鎖
   - 按「完成這組」，記下畫面出現什麼
   - 如果進入了休息狀態，再按「+15 秒」，記下畫面出現什麼
   - 解鎖手機，回覆你完成了
3. 收集證據：
   - 用 xcrun devicectl 從 App 的資料容器取出診斷紀錄檔；拿不到的話，請我打開「診斷紀錄」頁截圖。
   - 收集手機的系統日誌（例如 log collect --device-udid，需要時請我輸入 Mac 的管理員密碼），篩選測試那段時間和 LiftLog、這三個 intent、SpringBoard、即時動態、App Intents 相關，以及含有 unlock、authentication、foreground 的紀錄。
   - 診斷紀錄、日誌和所有輸出都只放在 tools/fixtures/，不能 commit。
4. 依證據判斷兩件事：
   - 按下按鈕後，perform 有沒有被執行？
   - 系統要求解鎖的原因是什麼？

## 3. 修正
- 依第 2 節找到的原因修正，讓「完成這組」「跳過休息」「+15 秒」在有密碼、鎖定的手機上都不用解鎖。
- 如果原因是 iOS 本身的限制（例如免費開發者帳號不允許，或某個必要的動作一定要解鎖），先停下來：在報告裡附上證據（日誌的關鍵幾行，去掉個人資料）和可行的替代做法，不要自己改成別的設計。
- 修正後，再請我在實機上照 2-3 的步驟重做一次，確認結果。

## 4. 收斂標準
建置與測試：
- G1：Debug 和 Release 都建置成功，0 個 error、0 個 warning。
- G2：全部測試通過；修正如果改到邏輯，要加上對應的測試。

實機（由我確認）：
- D1：手機鎖定時，「完成這組」「跳過休息」「+15 秒」都不會要求解鎖。
- D2：診斷紀錄顯示三個 intent 的 perform 都被執行而且成功。
- D3：解鎖打開 App 後，訓練畫面已經同步（組已打勾、休息倒數正確）。

程式碼檢查：
- S1：診斷紀錄的程式全部在 #if DEBUG 裡。
- S2：診斷紀錄、系統日誌和所有輸出都在 tools/fixtures/ 底下，沒有被 commit（用 git status 和 git log --all 確認）。

## 5. 最終報告
tools/CHANGE_17_REPORT.md 包含：
- 根本原因，以及支持它的證據（日誌和診斷紀錄的關鍵內容，去掉個人資料）
- 2-1 靜態檢查的完整表格
- 修正了什麼、為什麼這樣修
- D1～D3 的結果
- 有沒有遇到「先停下來」的情況
- 自行決定的事項
- 未解決的事項
- commit 列表

推上 GitHub 之後，告訴我報告的位置。

## 6. 最後一步：更新簽署並安裝到 iPhone
照 CLAUDE.md「每一份 CHANGE 的最後一步」執行，並在最後的訊息裡告訴我新簽署檔的到期日。
