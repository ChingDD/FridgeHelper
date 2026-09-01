# FridgeHelper Release Tickets

## 已完成

### 食材 CRUD 基礎
- 已支援新增、編輯、刪除食材。
- 欄位包含名稱、數量、到期日、備註、標籤、圖片、儲存位置。

### 列表互動
- 已支援左滑刪除。
- 已支援在列表內直接用 `+/-` 調整數量。

### 搜尋 / 標籤 / 位置 / 排序
- 已支援關鍵字搜尋，並有 200ms debounce。
- 已支援標籤篩選與儲存位置篩選。
- 已支援到期日與數量排序。

### 圖片支援
- 已支援拍照與從相簿選圖。
- 圖片儲存時會轉成 JPEG，壓縮比為 0.5。

### 基礎 UI / UX
- 已完成啟動動畫。
- 已完成空狀態提示。
- 已完成即時表單驗證。
- 已使用台灣日期格式。

### 食材 cell 狀態 UI
- 已改成圓形狀態圖示與指定底色規格。
- 已包含「未過期 / 快過期 / 已過期」三種狀態樣式。

### 到期資訊顯示規格
- 列表已依規格顯示過期年月份，以及距離過期剩幾天。

### 過期提醒基礎版
- 已支援過期前 3 天與當天過期推播通知。

### 主畫面即將過期 badge
- 已完成即將過期數量 badge 與查看即將過期食材列表的流程。

### 冰箱擺放位置自訂
- 已完成冰箱擺放位置自訂功能。

### iCloud 家庭分享
- 已完成家庭分享基礎功能。
- 已完成成員清單顯示。
- 已完成邀請成員功能。
- 已完成共享狀態處理。

### 列表上方數量 counter
- 已顯示 `食材 已新增 / 可新增` 的數量資訊。
- 已改為只計算自己 zone 的食材，共享冰箱不計入。

### 食材數量上限控管 - 階段一
- 已建立集中式方案限制 `FridgePlan`，免費版 100 項、家庭版 500 項不再散落於 ViewController。
- 已將方案來源抽成 `FridgePlanProviding`，目前固定回傳免費方案。
- 已在按下「＋」與表單儲存前各檢查一次容量，被擋下時保留表單內容。
- 已確保更新與刪除不受容量限制。
- 未套用容量限制於 CloudKit 同步，sharedDB 與自己的 zone 都維持完整同步。

### 多冰箱資料基礎 - 階段二（2A／2B／2C）

**2A：本機資料基礎**

- 已新增 `Fridge` @Model，`fridgeID` 為字串化 zoneID（格式 `"<ownerName>|<zoneName>"`）。
- 已在 `Item` 新增 `fridgeID`；只存本機、不寫進 CKRecord，雲端的真相是 record 所在的 zoneID。
- 已將標籤與儲存位置從 UserDefaults 搬進 `Fridge`，`StringListViewModel` 的 store 抽成 protocol。
- 已完成一次性遷移：建立 Default 冰箱、共享冰箱依 `zoneOwnerName` 分組、既有食材歸戶、清單複製。
- 已讓 `MainViewModel` 與兩個 `StringListViewModel` 綁定選定冰箱，不再是全 App 單例。

**2B：雲端路由與多 private zones**

- 已讓 `ZoneManaging` 支援任意 zone（`ensureZoneExists(_ zoneID:)`），非自己的 zone 自動略過。
- 已讓 `CloudRepository` 依 `item.fridgeID` 還原 zoneID 來路由；在別人的冰箱新增食材會寫入 sharedDB。
- 已將 `SyncCoordinator` 的 private 與 shared 合併成同一條流程：先問 database 哪些 zone 變動，再逐 zone 抓差異。private 端不再只同步固定那一座 zone。
- 已引入 `FridgeMetadata` CKRecord（`fridgeID`／`plan`／`createdAt`／`updatedAt`），每個 zone 固定一筆。
- 已讓 `SubscriptionManager` 的 privateDB 訂閱從 `CKRecordZoneSubscription` 改為 `CKDatabaseSubscription`，新增的 zone 才收得到 silent push；舊的 zone 訂閱會 best-effort 刪除。
- 已讓共享冰箱的方案改讀 `Fridge.plan`（即同步下來的 `FridgeMetadata.plan`），自己的冰箱維持看本機購買權益。

**2C：sharedDB 多 Zone**

- 已將 `ShareManager` 改為綁定單一 zone，每座冰箱各自建立 CKShare。
- 已修掉 `fetchParticipatingShare()` 只取 `zones.first` 的限制，改為直接查該座冰箱的 zone-wide share。
- 已將共享冰箱初始名稱改用 `CKShare.owner` 命名為「XXX 的冰箱」，取不到身分才退回「共享的冰箱」。
- 已將姓名解析抽成 `CKShare.Participant.identityName／displayName`，與 `ParticipantsViewModel` 共用同一份邏輯。

**`FridgeMetadata` 的定案**

- 不加 `schemaVersion`。目前 App 尚無其他使用者，不急著做版本協商。
- 寫入採「先讀再改」：不會抹掉新版寫入、本版還不認識的欄位，因此不需要靠版本協商保護。
- 內容沒變就不寫，避免每次啟動都讓其他裝置收到無意義的 silent push。
- 只有 Owner 會寫。成員的方案來源是自己的購買權益，讓成員寫回去會把 Owner 的家庭版蓋成免費方案。
- 讀取端不信任 record 裡的 `fridgeID` 欄位（那是 Owner 視角的值），一律以 `record.recordID.zoneID` 為準。

**上線前的必要步驟**

- `FridgeMetadata` 在 Development 環境由第一次寫入自動建立，要上 Production 必須到 CloudKit Console 執行 Deploy Schema Changes。只用 `record(for:)` 與 zone changes，不需要建 index。

### [Bug] shared zone change token key 碰撞

- 已於 commit `9ae1be8` 修正，token key 改為包含 database scope、`ownerName` 與 `zoneName`。
- 舊 key 因格式不同不會再被讀取，對應 zone 的 token 視為不存在而自動做一次完整同步，不需要額外的遷移程式。

## 未完成

### 食材數量上限控管（[定案版商業規格＋技術設計](FridgeBusinessAndTechnicalDesign.md)）

- 階段三：完成多冰箱 UI 與共享；新增冰箱選擇首頁、建立／重新命名／刪除冰箱、逐冰箱成員管理及 sharedDB 寫入。
- 階段四：完成 StoreKit 家庭版永久內購；可擁有三座冰箱、每座 500 項、每座最多邀請 4 位成員，並支援購買、Restore、退款及撤銷權益。
- 階段五：完成多設備競態、新設備恢復、多 shared zones、共享撤銷、離線與 StoreKit Sandbox 測試。

階段一已預留的接點：

- 階段四完成 StoreKit 後，只需在 `LunchingViewController` 改注入依購買權益判斷的 `FridgePlanProviding` 實作。

階段二留給階段三的接點：

- `LunchingViewController.loadSelectedFridge()` 目前固定退回 Default 冰箱，接上冰箱選擇首頁後改由該頁決定，其餘組裝流程不必調整。
- 新增冰箱時 zone 名稱用 `Fridge_<UUID>`，Default 冰箱沿用 `ShareZone` 不遷移。
- 建立冰箱後需呼叫 `FridgeMetadataRepository.upsert(for:)`，否則空冰箱在其他裝置上不會出現。

#### 階段二的已知限制

- 成員頁在 participant 裝置上會顯示「尚未共享冰箱」。共享已是逐冰箱的，但選定冰箱在冰箱選擇首頁做出來之前一律是自己的 Default 冰箱。與 2A 之後的食材列表行為一致，階段三接上選擇首頁即恢復。
- 標籤與儲存位置清單仍是本機各自的，同一座共享冰箱不同成員看到的清單不一致。要一致需將清單同步進 `FridgeMetadata`。
- 遷移的精度限制：舊有 shared Item 只存了 `zoneOwnerName`、沒有 zoneName，遷移時只能假設 `zoneName = "ShareZone"`。舊版本來就只支援單一 Zone，因此安全。

### 共享 zone 被撤銷時本機資料未清除

- 現況：`SyncCoordinator` 在 `deletedZoneIDs` 只清除 change token。
- 影響：對方撤銷共享、或自己在別台裝置刪掉冰箱後，本機的 `Fridge` 與其所有 `Item` 會一直留著，成為讀不到雲端的孤兒資料。
- 修正：一併刪除本機 `Fridge`、該 `fridgeID` 的所有 Item 及 token；`SwiftDataItemRepository` 需新增 `deleteAll(fridgeID:)`。
- 相依：刪掉的若是目前選定的冰箱，需要退回其他冰箱，因此建議與階段三的冰箱選擇首頁一起做。

### [Risk] CKRecord 未知欄位會被舊版以 `.allKeys` 抹除

- 現況：`CloudRepository.update()` 使用 `savePolicy: .allKeys`，而 `ItemRecordMapper.item(from:)` 只映射已知欄位。
- 情境：新版在 record 上寫入新欄位；舊版裝置同步下來時丟棄該欄位，使用者在舊版改動任一屬性後，`toRecord()` 重建的 record 不含該欄位，`.allKeys` 整筆覆蓋即抹除雲端資料。共享冰箱中只要有一位成員未更新 App 就會發生。
- 影響：新版寫入的欄位在其他裝置上消失。
- 解法方向一：改寫入策略，或在 mapper 保留 CKRecord 上的未知欄位並於寫回時帶上。這才是根本解，且不需要版本協商。
- 解法方向二：在 `FridgeMetadata` 加 `schemaVersion`，舊版偵測到版本高於自己時將該冰箱轉唯讀或提示更新。
- 2B 定案：不做版本協商，`FridgeMetadata` 不加 `schemaVersion`。目前 App 尚無其他使用者，且 `schemaVersion` 只能保護「加入檢查之後發出的版本」。
- 2B 已處理的部分：`FridgeMetadata` 的寫入採「先讀再改」，未知欄位由結構本身保住，不受此問題影響。
- 仍未處理：`Item` 的 `.allKeys` 寫入。要根本解需改寫入策略，或讓 `ItemRecordMapper` 保留 CKRecord 上的未知欄位並於寫回時帶上。

### CKShare title 對受邀者沒有資訊

- 現況：`ShareManager.fetchOrCreateShare()` 將 CKShare title 寫死為「我的冰箱」，`ParticipantsViewController.itemTitle(for:)` 也是。
- 說明：CKShare title 顯示在系統的邀請 UI（iMessage 邀請卡片、iOS 設定的共享項目），受邀者在接受邀請之前只看得到它，與 App 內的本機冰箱名稱是兩回事。
- 修正：改成帶入 Owner 端該冰箱的名稱。2C 之後 `ShareManager` 已綁定單一 `Fridge`，只需在建構時一併保存 `fridge.name` 並改寫這兩處。

### 通知可設定化
- 需提供通知開關。
- 開啟後可自訂提前幾天通知。

### 掃描收據自動加入食材
- 需支援相機拍攝收據。
- 需使用 Vision / OCR 辨識品項。
- 需讓使用者確認後批次加入。

### 掃描電子發票 QR Code
- 需支援掃描台灣電子發票 QR Code。
- 需解析品項資料。
- 需讓使用者確認後加入食材清單。

### 多國語系
- 需支援語系切換。
- 需補上在地化文案。

### 設定頁
- 需新增 navigation bar item。
- 需包含通知開關、自訂到期前幾天通知、清空冰箱、多國語系、AI 次數、意見回饋。

### QR / 發票使用次數控管
- 需顯示並控管 QR Code / 發票功能的剩餘次數與總次數 `10/10`。

### iCloud 家庭分享 - 移除特定成員
- 目前家庭分享其他能力已完成。
- 尚缺「移除特定成員」功能。

## Enhance

### AI Intelligent 加入 / 刪除食材
- 需讓 AI 協助處理特定食材的新增與刪除。
- 需套用次數限制。

### 食譜推薦
- 需根據冰箱現有食材推薦食譜。
- 可優先顯示使用即將過期食材的食譜。

### 食譜管理
- 需支援手動建立或 AI 推薦食譜。
- 需補上食譜搜尋與篩選。

### 食譜篩選
- 食譜可依最短時間、最簡單、最困難、最喜歡篩選。

### 食材自動扣庫存
- 食譜的食材數量設定後，可自動扣掉庫存。

### AI 使用次數控管
- 需顯示並控管 AI Intelligent 的剩餘次數與總次數 `5/5`。
