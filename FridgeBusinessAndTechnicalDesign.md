# 冰箱方案定案版商業規格＋技術設計

## 文件狀態

- 狀態：已定案
- 付費模式：免費版＋家庭版非消耗型永久內購
- 核心原則：付費權益跟著冰箱 Owner；食材同步永遠不受方案額度阻擋

## 商業方案

| 權益 | 免費版 | 家庭版永久買斷 |
|---|---:|---:|
| 可擁有冰箱 | 1 座 Default | 3 座，Default＋2 座 |
| 每座自己冰箱的食材上限 | 100 項 | 500 項 |
| 每座可邀請成員 | 1 位 | 4 位 |
| 可加入別人分享的冰箱 | 不限制 | 不限制 |
| sharedDB 食材是否占自己的額度 | 否 | 否 |
| ShareZone／sharedDB 同步 | 永遠完整 | 永遠完整 |
| 查看、更新、刪除既有食材 | 永遠允許 | 永遠允許 |

家庭版每座最多邀請 4 位成員，Owner 不計入，因此同一座冰箱最多 5 人共同管理。待接受邀請也占用名額，避免同時送出過多邀請。

「免費版一座冰箱」指使用者只能擁有一座冰箱，不代表只能看到一座。使用者加入別人分享的冰箱不占自己的冰箱名額。

## 權益歸屬

每座冰箱的容量與共享人數由該冰箱 Owner 的方案決定，成員自己的購買狀態不會升級別人的冰箱。

### 免費 Owner＋家庭版成員

- 冰箱上限仍為 100 項。
- 最多仍只能邀請 1 位成員。
- 家庭版成員不能用自己的權益升級這座冰箱。
- 達上限時顯示「此冰箱已達 100 項上限，請由冰箱擁有者升級家庭版」。

### 家庭版 Owner＋免費成員

- 冰箱上限為 500 項。
- 最多可邀請 4 位成員。
- 免費成員可共同新增、更新、刪除食材，不需要自行購買。

### 家庭版 Owner 的所有冰箱

- 現有 Default 冰箱購買後立即由 100 提升為 500。
- 解鎖第二、第三座冰箱。
- 三座冰箱每座各有 500 項額度，不共用總額度。
- 後續建立的第二、第三座冰箱一開始就是 500 項。

## 冰箱首頁

首頁分成「我的冰箱」與「與我共享」：

```text
我的冰箱                         家庭版
├─ 家裡冰箱             82 / 500
├─ 公司茶水間          340 / 500
└─ 度假屋冰箱           16 / 500

與我共享
├─ 爸媽家的冰箱         75 / 100    Owner：爸爸
├─ 女友家的冰箱        126 / 500    Owner：女友
└─ 辦公室冰箱           48 / 100    Owner：管理員
```

- 「我的冰箱」才占可擁有冰箱名額。
- 「與我共享」不占冰箱名額，也不占自己的食材額度。
- 記住使用者上次選取的冰箱。
- 共享冰箱較多時，可再提供搜尋、收藏或最近使用排序。
- 使用者可以離開共享冰箱，但不能刪除 Owner 的資料。

## 食材額度規則

### 手動新增

新增食材時依目前選取的冰箱判斷：

1. 取得目前冰箱的 Zone。
2. 取得該 Zone Owner 的方案。
3. 計算該冰箱目前的食材數量。
4. 達到上限就阻擋新增。

不得使用 local DB 全部食材數量判斷，必須使用目前 `fridgeID`／Zone 的食材數量。

容量應在兩個時間點檢查：

- 使用者按下新增按鈕時。
- 表單實際儲存前再次檢查，避免開啟表單後其他設備又新增食材。

### 更新與刪除

即使冰箱已經超額，仍然允許：

- 修改名稱、數量、期限、照片、備註及標籤。
- 刪除食材。
- 將上述變更同步至 CloudKit 與其他設備。

### 多設備同時新增

例如冰箱目前有 99 項，兩台設備同時新增後成為 101 項：

- 兩項都保留。
- 不自動刪除資料。
- 後續新增全部阻擋。
- 刪到 99 項後，才能再新增第 100 項。

目前架構採 local-first 與 CloudKit best-effort，上限屬於最終一致的商業限制，不保證跨設備絕對原子化。若未來需要嚴格上限，必須增加 counter record、record change tag 重試及原子寫入設計。

### 未來其他新增入口

收據 OCR、電子發票、AI 新增等使用者主動建立食材的入口，都必須使用同一套容量政策。CloudKit 接收端同步不套用容量政策。

## CloudKit 同步規則

以下同步永遠不檢查食材上限：

- 自己 privateDB 內所有冰箱 Zone。
- sharedDB 內所有受邀冰箱 Zone。
- 新設備第一次同步。
- App 重裝後恢復。
- Silent push 差異同步。
- 接受 CKShare 後的初次同步。

同步行為：

- 新 Record：完整新增至本機。
- 已存在 Record：完整更新。
- 刪除 Record：完整刪除。
- 不因免費上限跳過任何 Record。
- 只有成功套用該批變更後才能保存新的 change token。

即使免費方案的某座冰箱在雲端已有 500 項，新設備也要下載完整 500 項，再進入超額狀態。

## 退款與權益撤銷

非消耗型 IAP 正常情況不會到期，但仍可能因退款或 Apple 撤銷交易而失效。StoreKit 必須監聽交易更新並處理 `revocationDate`。

### Default 冰箱

- 保留全部資料並完整同步。
- 回到免費上限 100。
- 超過 100 時不能新增。
- 仍可更新與刪除。

### 額外兩座冰箱

進入維護模式：

- 保留冰箱與全部資料。
- 永遠完整同步。
- 可以查看、更新、刪除。
- 不能新增食材或成員。
- 不能再建立新冰箱。

### 已有共享成員

- 不主動移除既有成員。
- 可以移除成員。
- 超過免費成員上限時不能新增邀請。
- 再次取得家庭版權益後立即恢復。

## App Store 家人共享

家庭版非消耗型 IAP 不開啟 Apple Family Sharing。

- App Store Family Sharing：關閉。
- FridgeHelper 家庭共享：使用 CloudKit CKShare。
- 一位購買者負責自己擁有冰箱的方案。
- 受邀成員共享該冰箱權益，但不取得建立三座家庭版冰箱的個人權益。

App Store Connect 一旦對 IAP 開啟 Family Sharing 就不能關閉，建立商品時需特別確認。

## 目標 CloudKit 架構

一座冰箱對應一個 `CKRecordZone`。

### 自己擁有的冰箱

```text
privateDB
├─ ShareZone                    Default，保留既有 Zone
├─ Fridge_<UUID>                第二座冰箱
└─ Fridge_<UUID>                第三座冰箱
```

### 別人分享的冰箱

```text
sharedDB
├─ 爸爸擁有的 ShareZone
├─ 女友擁有的 Fridge_<UUID>
└─ 公司管理員擁有的 Fridge_<UUID>
```

### Zone 內容

```text
FridgeMetadata
├─ fridgeID
├─ displayName
├─ tier
├─ schemaVersion
├─ createdAt
└─ updatedAt

Item
Item
Item
CKShare
```

`FridgeMetadata` 是未來新增的自訂 CKRecord，目前不存在。它保存冰箱資料，不把 `itemCount` 當唯一真相。一般顯示由本機該 `fridgeID` 的 Item 數量計算，避免多設備同時寫入 counter 產生 lost update。

目前 Zone 主要包含 Item Record、Item 圖片欄位使用的 CKAsset，以及共享後存在的 CKShare Record。

## 本機 SwiftData 模型

### Fridge

未來新增 `Fridge` Model：

| 欄位 | 用途 |
|---|---|
| `id` | App 內穩定識別碼 |
| `name` | 冰箱顯示名稱 |
| `zoneName` | CloudKit Zone 名稱 |
| `zoneOwnerName` | CloudKit Zone Owner |
| `tier` | `free`／`familyLifetime` |
| `schemaVersion` | 資料格式版本 |
| `createdAt` | 建立時間 |
| `updatedAt` | 更新時間 |

是否為自己的冰箱可由 `zoneOwnerName` 判斷，不需額外保存 `isOwned`。

### Item

目前 Item 只有 `zoneOwnerName`，只能知道資料屬於誰，無法區分同一個 Owner 的不同 Zone。未來至少需要保存 `zoneOwnerName＋zoneName`，本機建議直接讓 Item 保存 `fridgeID`。

例如 Jeff 擁有：

```text
Jeff／ShareZone       家裡冰箱
Jeff／Fridge_ABC      公司冰箱
```

兩座冰箱的 Owner 都是 Jeff，只保存 `zoneOwnerName` 無法判斷 Item 應顯示或寫回哪座冰箱。

## 方案限制的程式設計

方案限制集中定義，不散落在 ViewController：

```text
Free
├─ ownedFridges: 1
├─ itemsPerFridge: 100
└─ invitedMembersPerFridge: 1

FamilyLifetime
├─ ownedFridges: 3
├─ itemsPerFridge: 500
└─ invitedMembersPerFridge: 4
```

邀請成員數不包含 Owner，但包含待接受邀請。

新增失敗至少要能區分：

- 自己是 Owner 且可購買家庭版。
- 自己是成員，必須請 Owner 升級。
- 家庭版冰箱已達 500 項。
- 額外冰箱因權益撤銷而處於維護模式。

## StoreKit 技術設計

新增集中式權益管理元件，負責：

- 取得家庭版非消耗型商品。
- 購買與 Restore Purchases。
- 讀取 `Transaction.currentEntitlements`。
- 驗證 StoreKit signed transaction。
- 監聽 `Transaction.updates`。
- 處理退款與 revocation。
- 發布目前是否擁有家庭版。

不能只將購買結果保存在 UserDefaults，StoreKit 驗證結果才是購買權益來源。

### 沒有自有後端的限制

- IAP 跟著 App Store 的 Media & Purchases 帳號。
- CloudKit Zone 跟著 iCloud 帳號，兩者不一定相同。
- 參與者無法直接驗證 Owner 的 StoreKit 購買，只能讀取 Zone 內的 `FridgeMetadata.tier`。
- Owner 退款後若未再次開啟 App，shared Zone 的方案 metadata 不會立即降級。

初期採 best-effort 模式。若未來需要嚴格綁定權益與即時處理退款，才加入自有帳號、後端、App Store Server Notifications 與 `originalTransactionID` 綁定。

## 現有架構調整

### ZoneManager

- 目前固定使用 `ShareZone`。
- 未來需建立、列出並操作任意 Zone。
- 保留既有 `ShareZone` 作為 Default。

### CloudRepository

- 目前 `add()` 永遠新增到自己的 Default private Zone。
- 未來新增時必須傳入目標冰箱。
- Owner 冰箱走 privateDB，別人分享的冰箱走 sharedDB。
- Fetch、count 與 CRUD 都以 `fridgeID` 為範圍。

### ShareManager

- 目前只處理固定 Zone，participant 只取 sharedDB 的第一座 Zone。
- 未來每座冰箱各自建立 CKShare。
- 分享與成員管理都必須傳入選定冰箱。
- 重新命名冰箱時同步更新 CKShare title。

### ParticipantsViewModel／ParticipantsViewController

- 目前成員頁屬於全域畫面。
- 未來改成選定冰箱的設定頁。
- 只有 Owner 能邀請、移除成員、停止分享與刪除冰箱。
- 邀請前依 Owner 方案檢查成員上限。

### SubscriptionManager

- 目前 privateDB 只訂閱一個固定 Zone。
- 多冰箱後應先取得發生變更的 private zones，再分別保存 per-zone change token。
- sharedDB 繼續以 database change＋zone change 方式同步。

### SyncCoordinator

- 同步所有 owned zones 與 shared zones。
- 同步 `FridgeMetadata` 與 Item。
- shared Zone 被撤銷時，清除本機 Fridge、其 Item 及 token。
- Token key 必須包含 database scope、ownerName 與 zoneName。

### SwiftDataItemRepository

新增以冰箱為範圍的操作：

- `fetch(fridgeID:)`
- `count(fridgeID:)`
- `deleteAll(fridgeID:)`

### MainViewModel

- 目前 `savedItems` 與 `savedItemCount` 是 local DB 全部資料。
- 未來 ViewModel 綁定一座選定冰箱。
- `savedItemCount` 改為該冰箱數量。
- `itemCapacity` 由該冰箱 Owner 的方案決定。

### FridgeViewController

- 由冰箱首頁傳入選定的 `fridgeID`、名稱、Owner、使用者角色與容量。
- 畫面沿用現有設計，但資料來源限定為選定冰箱。
- 「＋」代表新增到目前選取的冰箱。

## Shared zone token key 碰撞

這是目前已存在的潛在 Bug，不是多冰箱功能才會發生。

不同 Owner 目前都使用相同 `zoneName = ShareZone`：

```text
爸爸／ShareZone
媽媽／ShareZone
```

現有 token key 只使用 zoneName，兩座 Zone 都會寫入：

```text
syncToken_sharedZone_ShareZone
```

結果可能互相讀取、覆蓋或刪除對方的 token，導致同步錯誤、反覆完整同步或漏套用變更。

正確 key 必須包含：

```text
databaseScope＋ownerName＋zoneName
```

修正時需刪除無法判斷 Owner 的舊 token、重建 sharedDB 同步進度，並對目前所有 shared zones 做一次完整同步。

## 現有資料遷移

1. 現有 `ShareZone` 直接成為 Default 冰箱。
2. 建立對應的本機 `Fridge`。
3. 在 `ShareZone` 新增一筆 `FridgeMetadata`。
4. 現有自己的 Item 全部指定到 Default `fridgeID`。
5. 現有 sharedDB Item 依完整 Zone ID 分組建立共享 Fridge。
6. 重新列舉並完整同步一次所有 private／shared zones。
7. 新版 token key 使用 database scope＋ownerName＋zoneName，舊 token 不沿用。
8. 不刪除既有 Item CKRecord，也不修改 Record ID。

## 開發順序

### 階段一：目前食材數量上限 Ticket

- 免費方案 Default 冰箱上限 100。
- 家庭版 Default 冰箱上限 500。
- 手動新增只計算自己的 ShareZone 食材。
- sharedDB 不計入自己的額度。
- ShareZone 與 sharedDB 永遠完整同步。
- 更新與刪除永遠允許。
- 建立集中式方案限制，避免使用 local DB 全部 `savedItems.count`。

### 階段二：多冰箱資料基礎

- 新增 Fridge SwiftData Model。
- Item 新增 `fridgeID`。
- ZoneManager 支援任意 Zone。
- Repository 依 fridge 路由。
- SyncCoordinator 支援多 Zone。
- 完成舊資料遷移。

### 階段三：多冰箱 UI 與共享

- 新增冰箱選擇首頁。
- FridgeViewController 改為單一冰箱範圍。
- 支援建立、重新命名、刪除冰箱。
- 成員管理改為單一冰箱範圍。
- 支援在有寫入權限的 sharedDB 冰箱新增食材。

### 階段四：StoreKit 永久內購

- 建立家庭版非消耗型商品、Paywall、購買與 Restore。
- 購買後將全部 owned fridge 升級成 500。
- 解鎖另外兩個冰箱名額。
- 處理 refund／revocation。
- 同步更新每座 owned fridge 的方案 metadata。

### 階段五：完整測試

- 多設備新增競態。
- 新設備完整恢復。
- 多個 shared zones 與 token 隔離。
- 邀請、撤銷及離開分享。
- 免費／家庭版 Owner 與不同方案成員的組合。
- 退款後超額資料及額外冰箱維護模式。
- Offline、重新連線、StoreKit Sandbox 購買、恢復與退款。

## 驗收條件

1. 免費使用者只能擁有 Default 冰箱，容量 100 項。
2. 家庭版使用者可擁有三座冰箱，每座容量 500 項。
3. 免費冰箱最多邀請 1 位成員。
4. 家庭版冰箱最多邀請 4 位成員，Owner 不計入。
5. 加入別人的冰箱不占自己的冰箱或食材額度。
6. 免費成員加入家庭版 Owner 的冰箱後，可共同管理 500 項。
7. 家庭版成員加入免費 Owner 的冰箱後，該冰箱仍只有 100 項。
8. 達上限時不能手動新增，但更新與刪除正常。
9. ShareZone 與 sharedDB 不因額度跳過任何 Record。
10. 新設備能下載全部超額資料。
11. 多設備同時新增造成超額時不刪除資料，後續新增被阻擋。
12. 第四座 owned fridge 被阻擋。
13. 退款後資料仍完整，額外冰箱進入維護模式。
14. Restore Purchases 後恢復三座冰箱與每座 500 項權益。
15. 不同 Owner 的同名 Zone 使用不同 change token。
16. shared Zone 被撤銷後，本機對應 Fridge、Item 與 token 正確清除。
