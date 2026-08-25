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

## 未完成

### 食材數量上限控管（[定案版商業規格＋技術設計](FridgeBusinessAndTechnicalDesign.md)）

- 階段二：建立多冰箱資料基礎；拆成 2A／2B／2C 三段，詳見下方。
- 階段三：完成多冰箱 UI 與共享；新增冰箱選擇首頁、建立／重新命名／刪除冰箱、逐冰箱成員管理及 sharedDB 寫入。
- 階段四：完成 StoreKit 家庭版永久內購；可擁有三座冰箱、每座 500 項、每座最多邀請 4 位成員，並支援購買、Restore、退款及撤銷權益。
- 階段五：完成多設備競態、新設備恢復、多 shared zones、共享撤銷、離線與 StoreKit Sandbox 測試。

階段一已預留的接點：

- 階段二綁定選定冰箱時，改注入 `MainViewModel.fridgeZoneOwnerName`，即可讓共享冰箱套用 Owner 的方案。
- 階段四完成 StoreKit 後，只需在 `LunchingViewController` 改注入依購買權益判斷的 `FridgePlanProviding` 實作。

#### 階段二拆解

- 2A：純本機資料基礎。Fridge Model、`Item.fridgeID`、逐冰箱標籤／儲存位置、既有資料遷移。不動 UI、不動 CloudKit 寫入路徑。
- 2B：`ZoneManager` 支援任意 Zone、`CloudRepository` 依 Fridge 路由（含在別人的冰箱新增食材時寫入 sharedDB）、`SyncCoordinator` 列舉所有 private zones、引入 `FridgeMetadata`。
- 2C：sharedDB 多 Zone 支援。修掉 `ShareManager.fetchParticipatingShare()` 只取 `zones.first` 的限制，每座冰箱各自建立 CKShare。

#### 階段 2A 定案內容

**ZoneID 的組成**

`CKRecordZone.ID` 只有 `zoneName` + `ownerName`，由 App 自行命名，唯一性也由 App 負責。

- privateDB：所有 Zone 的 `ownerName` 都是 `__defaultOwner__`，只靠 `zoneName` 區分。Default 冰箱沿用 `ShareZone`，新增的用 `Fridge_<UUID>`。
- sharedDB：不同 Owner 的 Zone 可以同名，必須 `zoneName + ownerName` 才唯一。

**Fridge Model 欄位**

| 欄位 | 說明 |
|---|---|
| `id` | 字串化的 zoneID，格式 `"<ownerName>\|<zoneName>"` |
| `name` | 冰箱顯示名稱；純本機，不同步 |
| `zoneName` | CloudKit Zone 名稱 |
| `ownerName` | CloudKit Zone Owner |
| `plan` | `free`／`familyLifetime` |
| `createdAt` | 建立時間 |
| `updatedAt` | 更新時間 |
| `tags` | 這座冰箱的標籤清單 |
| `locations` | 這座冰箱的儲存位置清單 |

- `id` 用字串化 zoneID，`SyncCoordinator` 可從 `record.recordID.zoneID` 直接算出 `fridgeID`，不必查表，也不會有「record 先到、Fridge 還沒建」的順序問題。
- `ownerName` 必須正規化：判定為自己的 Zone 時一律寫入 `CKCurrentUserDefaultName`。同一座冰箱在 Owner 裝置上看到 `__defaultOwner__`、在 participant 裝置上看到真實 user record name，不正規化會在本機產生兩筆 Fridge。
- 本機 Fridge 不放 `schemaVersion`。本機資料格式版本由 SwiftData migration 管，雲端版本協商見下方獨立 ticket。
- `FridgePlan` 需加上 `String, Codable` raw value 才能穩定持久化到 SwiftData。

**冰箱名稱**

- 名稱一律存在本機，不同步給其他成員，因此 `FridgeMetadata` 不需要 `displayName`。
- 共享冰箱初始名稱為 `<分享者>'s 冰箱`，取名來源是 `CKShare.owner.userIdentity`，邏輯與 `ParticipantsViewModel.mapMembers` 相同（nameComponents → email → phone），fallback 為「共享的冰箱」。
- 使用者可自行改名，僅影響本機。

**標籤與儲存位置逐冰箱**

- 從 UserDefaults 搬進 SwiftData，直接掛在 `Fridge` 上。資料跟著冰箱生命週期走，刪除冰箱或共享被撤銷時一併清除。
- `StringListViewModel` 的 store 抽成 protocol，新增讀寫 `Fridge` 欄位的實作；`ManageListViewController` 不需修改。
- 遷移時把現有 `app.swiftdata.tags` 與 `app.swiftdata.storeLocations` 複製給所有既有 Fridge，新建或新加入的冰箱使用系統預設值。
- 已知限制：2A 的清單是本機各自的，同一座共享冰箱不同成員看到的清單不一致。要一致需等 2B 的 `FridgeMetadata`。

**其他決定**

- `fridgeID` 只存在本機，不寫進 CKRecord。雲端的真相是 zoneID，同步時反推。
- 共享冰箱的食材在本機 SwiftData 一樣有一份（local-first 快取），只有雲端寫入路徑走 sharedDB。
- `MainViewModel` 與兩個 `StringListViewModel` 必須在選定冰箱時才建立，不能再是全 App 單例。`LunchingViewController` 改成 `makeMainViewModel(for: Fridge)` 形式，2A 先固定注入 Default 冰箱，階段三接上選擇首頁時直接沿用。
- 遷移的已知精度限制：舊有 shared Item 只存了 `zoneOwnerName`、沒有 zoneName，遷移時只能假設 `zoneName = "ShareZone"`。舊版本來就只支援單一 Zone，因此安全。

**實作項目**

1. `FridgePlan` 加 `String, Codable` raw value。
2. 新增 `Fridge` @Model。
3. `Item` 新增 `fridgeID`；`SwiftDataStack` 註冊 `Fridge.self`。
4. 一次性遷移：建立 Default Fridge、共享 Fridge 依 `zoneOwnerName` 分組、Item 歸戶、清單從 UserDefaults 複製。
5. `ItemRepositoryProtocol` 新增 `fetch(fridgeID:)` 與 `count(fridgeID:)`。
6. `StringListViewModel` 的 store 改為 protocol 加 Fridge-backed 實作。
7. `MainViewModel` 綁定 `selectedFridgeID`，`savedItemCount` 改用 `count(fridgeID:)`，上次選取的冰箱記在 UserDefaults。
8. `LunchingViewController` 改成 per-fridge 組裝。
9. `SyncCoordinator` 依 record 的完整 zoneID 歸戶，Fridge 不存在就自動建立。

拆成兩個 commit：1–5 為資料模型與遷移，6–9 為 per-fridge 組裝。

### [Risk] CKRecord 未知欄位會被舊版以 `.allKeys` 抹除

- 現況：`CloudRepository.update()` 使用 `savePolicy: .allKeys`，而 `ItemRecordMapper.item(from:)` 只映射已知欄位。
- 情境：新版在 record 上寫入新欄位；舊版裝置同步下來時丟棄該欄位，使用者在舊版改動任一屬性後，`toRecord()` 重建的 record 不含該欄位，`.allKeys` 整筆覆蓋即抹除雲端資料。共享冰箱中只要有一位成員未更新 App 就會發生。
- 影響：新版寫入的欄位在其他裝置上消失。
- 解法方向一：改寫入策略，或在 mapper 保留 CKRecord 上的未知欄位並於寫回時帶上。這才是根本解，且不需要版本協商。
- 解法方向二：在 `FridgeMetadata` 加 `schemaVersion`，舊版偵測到版本高於自己時將該冰箱轉唯讀或提示更新。
- 時間點：`schemaVersion` 只能保護「加入檢查之後發出的版本」，補得越晚能保護的裝置越少。目前 App 尚無其他使用者，因此不急著做版本協商，優先考慮解法一，於 2B 引入 `FridgeMetadata` 時一併定案。

### CKShare title 對受邀者沒有資訊

- 現況：`ShareManager.fetchOrCreateShare()` 將 CKShare title 寫死為「我的冰箱」。
- 說明：CKShare title 顯示在系統的邀請 UI（iMessage 邀請卡片、iOS 設定的共享項目），受邀者在接受邀請之前只看得到它，與 App 內的本機冰箱名稱是兩回事。
- 修正：改成帶入 Owner 端該冰箱的名稱。

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

### [Bug] shared zone change token key 碰撞

- 現況：shared zone token key 只包含 `zoneName`；不同 Owner 都使用 `ShareZone` 時會共用 `syncToken_sharedZone_ShareZone`。
- 情境：同一位使用者加入「爸爸／ShareZone」與「媽媽／ShareZone」後，兩座 Zone 會互相讀取、覆蓋或刪除對方的 token。
- 影響：可能造成 change token 錯誤、同步失敗、反覆完整同步或漏套用變更。
- 修正：token key 改為包含 database scope、`ownerName` 與 `zoneName`，並集中管理 token key 的建立方式。
- 遷移：清除無法判斷 Owner 的舊 shared zone token、重建 sharedDB 同步進度，並對現有所有 shared zones 執行一次完整同步。

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
