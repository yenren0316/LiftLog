# CHANGE_12：改用 iOS 26 內建的計時、轉場與標題

## 0. 開始之前
1. 把這份 prompt 的原文存成 tools/changes/CHANGE_12.md。
2. 讀 CLAUDE.md、SPEC.md、tools/STATUS.md 和 tools/CHANGE_11_REPORT.md，了解目前的狀態。
3. 把下面「每一份 CHANGE 的最後一步」整段加進 CLAUDE.md，從這次開始執行（第 6 節）。

### 每一份 CHANGE 的最後一步：更新簽署並安裝到 iPhone
我用的是免費的開發者帳號，簽署檔只有 7 天效期，所以每次優化完順便延長。
1. 在報告寫完、推上 GitHub 之後才做。
2. 在 ~/Library/Developer/Xcode/UserData/Provisioning Profiles（舊版 Xcode 也檢查 ~/Library/MobileDevice/Provisioning Profiles）裡，用 security cms -D -i 讀出每個簽署檔的 App ID，只刪除屬於這個 App 和它的擴充（小工具、即時動態）的簽署檔。不刪其他 App 的簽署檔，也不刪憑證。
3. 用 xcodebuild 加 -allowProvisioningUpdates 重新建置 Debug 給實機，讓 Xcode 產生新的簽署檔。
4. 用 xcrun devicectl 把 App 覆蓋安裝到已連接的 iPhone（接線或同一個網路都可以）。
5. 絕對不能從手機刪除 App，也不能用任何會刪除 App 資料的安裝方式：訓練紀錄只存在手機本機。
6. 在最後回覆我的訊息裡，告訴我新簽署檔的到期日（不用寫進報告）。
7. 手機沒有連接、沒有解鎖，或安裝失敗時，跳過這一步，在最後的訊息裡提醒我自己用 Xcode 按 Run。
8. DEVELOPMENT_TEAM 等簽署設定照舊不 commit。

前提：CHANGE_11 已完成並推上 GitHub。
這次一樣一次做完，CLAUDE.md 裡的執行規則繼續適用。完成後產出 tools/CHANGE_12_REPORT.md，並同步更新 SPEC.md 和 tools/STATUS.md。每一節各自 commit。
原則：能用 iOS 26 內建行為的，就不要自己寫。遇到這份 prompt 列出的「先停下來」情況時，在報告裡說明，不要自己另寫一套。

## 1. 計時改用系統的計時文字
- 經過時間（ElapsedTimeText）和休息倒數（RestTimerBar）改用 Text(timerInterval:countsDown:) 和 ProgressView(timerInterval:)，讓系統自己跳秒，不再用 TimelineView 每秒重畫。
- 範圍包括訓練畫面的經過時間、休息倒數條、附屬列的「訓練中」，以及其他所有顯示經過時間或倒數的地方。
- 顯示格式要和現在一樣：不到 1 小時是「0:54」「24:30」，超過 1 小時是「1:05:30」。
- 「跳過休息」「+15 秒」之後，倒數要立刻正確更新。
- 如果系統的計時文字沒辦法做到相同的格式或行為，那個地方維持原樣，在報告裡說明。

## 2. 訓練中畫面的放大轉場
- 點附屬列的「訓練中」橫條時，用 matchedTransitionSource ＋ .navigationTransition(.zoom) 從橫條放大成全螢幕的訓練畫面，像「音樂」的迷你播放器。
- 按訓練畫面左上角的收合按鈕，或往下拖關閉時，要縮回附屬列的橫條。
- 從「下一次」卡、小工具或其他入口開始訓練時，照原本的方式打開（全部仍然走 WorkoutLauncher）。
- 如果附屬列不支援 matchedTransitionSource，或放大轉場和附屬列互相衝突，先停下來，維持原本的 fullScreenCover。

## 3. 「今天」分頁改用系統的大標題
- 拿掉自己畫的 ScreenHeader，改用 navigationTitle("今天") ＋ .navigationBarTitleDisplayMode(.large)，和其他三個分頁一致，iOS 26 的捲動邊緣效果也跟著系統。
- 首頁仍然要一個畫面放得下（CHANGE_07 的 V1 標準）。放不下時，先停下來，附上截圖和差了多少高度。
- ScreenHeader 如果沒有其他地方在用，一起刪掉。

## 4. 收斂標準
建置與測試：
- G1：Debug 和 Release 都建置成功，0 個 error、0 個 warning。
- G2：全部測試通過，包括以下新測試：
  - UI 測試：點附屬列的橫條會打開訓練畫面，收合後回到附屬列
  - UI 測試：-demoWorkoutElapsed 為 1 小時以上時，經過時間顯示成「1:05:30」這種格式；不到 1 小時顯示成「24:30」這種格式
  - UI 測試：按「+15 秒」和「跳過休息」後，休息倒數立刻更新

程式碼檢查：
- S1：ElapsedTimeText、RestTimerBar 不再使用 TimelineView（維持原樣的地方要在報告裡列出原因）。
- S2：ScreenHeader 沒有殘留的使用。
- S3：新增的 DEBUG 參數都在 #if DEBUG 裡。

畫面驗證（截圖存到 tools/screens/change12/）：
- V1：今天分頁使用系統的大標題，一個畫面放得下。
- V2：放大轉場的中間畫面一張，以及收合回附屬列之後一張。
- 每輪重跑歷程穩定性的四組連拍比對。

只能在實機確認的項目寫進報告：放大轉場和收合的手感、計時跳秒是否順暢、耗電。

## 5. 最終報告
tools/CHANGE_12_REPORT.md 包含：
- 每一條收斂標準的結果
- 第 1～3 節有沒有遇到「先停下來」的情況，以及原因
- 自行決定的事項
- 未解決的事項
- 實機確認清單
- 截圖索引
- commit 列表

推上 GitHub 之後，告訴我報告的位置。

## 6. 最後一步：更新簽署並安裝到 iPhone
照 CLAUDE.md「每一份 CHANGE 的最後一步」執行，並在最後的訊息裡告訴我新簽署檔的到期日。
