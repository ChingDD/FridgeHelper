# CloudKit 同步流程(syncCloudToLocal)

`AppDelegate.syncCloudToLocal` 的作用:**把雲端的變更拉回本地,並確保多次同步一個接一個跑,不會互相蓋掉。**

## 何時會跑這段

會觸發:**App 啟動、收到遠端通知(別台設備改了東西)、接受共享、明確呼叫 `syncFromCloudIfNeeded()`**。

> ⚠️ 本機按按鈕新增/編輯/刪除**不會**跑這段。那是「寫入路徑」(更新 cache → 寫 SwiftData → 背景寫 CloudKit)。
> 這段是給**接收端**用的:當這台設備收到「雲端有變更」的通知時,把變更拉回來。

## 程式碼

```swift
private var syncTask: Task<Void, Error>?

func syncCloudToLocal(shouldNotifyChanges: Bool = false) async throws {
    let previous = syncTask          // ① 抓住上一條(可能還沒做完的)同步
    let task = Task {                // ② 建立新任務(建立即排程,但要等 main thread 空出來才跑)
        _ = try? await previous?.value   // ③ 先等上一條做完;try? 是「就算上一條失敗也不連累我」
        try await self.performSync(shouldNotifyChanges: shouldNotifyChanges)  // ④ 再做自己的同步
    }
    syncTask = task                  // ⑤ 把「鏈尾」更新成自己,讓下一條能接在後面
    try await task.value             // ⑥ 讓出 main thread、等自己做完;try 把自己的錯誤往外拋
}
```

`performSync` 做的事:`fetchChanges()` 從 CloudKit 抓變更寫進本地 SwiftData → (需要時)發本機通知 →
post `.cloudKitDataDidChange` → `MainViewModel.loadItems()` 重讀 SwiftData → UI 更新。

## 核心設計:序列化排隊

**目的:** 短時間收到多個變更通知時,避免兩條 sync 交錯,較舊的雲端快照晚套用、蓋掉較新的資料。

**機制:** 每條新任務在做自己的事之前,先 `await` 上一條(③);`syncTask` 永遠指向最後一條,形成一條鏈(C 等 B、B 等 A)。第一條因為 `previous == nil`,直接跳過等待、立刻執行。

## 完整流程(連續兩個變更通知的例子)

設備 B 改了東西 → CloudKit 推播 → 設備 A 短時間收到**兩則**通知:

```
通知① 到 → syncCloudToLocal()
   previous = nil
   建 task① → syncTask = task①
   await task①.value          ← 讓出 main thread
   task① body:previous 是 nil → 跳過等待 → performSync(抓第一批變更…等網路)
          │
          │  ← task① 等網路、main thread 空著時…
          ▼
通知② 到 → syncCloudToLocal()   (趁空檔擠進 MainActor)
   previous = syncTask = task① ← 抓到「還沒做完的」task①
   建 task② → syncTask = task②
   await task②.value          ← 讓出
   task② body:await task①.value → task① 還沒好,卡在這裡等 ⏸
          │
task① performSync 做完 → 本地更新 → task① 完成 ✅
          │
task② 的 await 恢復 → 現在才 performSync(抓第二批變更)→ 完成 ✅
```

兩次同步**一前一後、不重疊**完成。

## 為什麼要排隊(沒有排隊會怎樣)

若拿掉排隊,task① 和 task② 同時打 CloudKit:

```
task①:抓到舊快照 v1(數量=5)────────► 寫入本地(較慢,晚到)
task②:抓到新快照 v2(數量=6)──► 寫入本地(較快,先到)
```

task② 先寫 6,task① 後寫**舊的 5** → 畫面數量從 6「倒退」回 5。
排隊保證 task② 一定等 task① 做完才抓,抓到的永遠是最新狀態,不會倒退。

## 前提:全部在 MainActor 上

`AppDelegate` 繼承 `UIResponder`(`@MainActor` class)且 conform `UIApplicationDelegate`(`@MainActor` protocol),
所以整個 class 及其方法(含 `syncCloudToLocal`)都是 **MainActor-isolated**;方法內 `Task { }` 也繼承此 context,在 main thread 執行。

**這是排隊能成立的地基:** 因為 `previous = syncTask`(讀)和 `syncTask = task`(寫)都在單一執行緒、不被打斷,才不會有 data race 把鏈接斷。若哪天把方法改成 `nonisolated`,這個保證就會消失。

## 啟動時 Fridge 資料的三步設計

`AppDelegate.didFinishLaunching` 對 `Fridge` 依序做三件事：

1. `ensureDefaultFridge()`：同步執行，只動本機
2. `try await syncCloudToLocal()`：雲端 → 本機
3. `await pushOwnedFridgeMetadata()`：本機 → 雲端

第 2、3 步在同一個 `do` 區塊裡，同步拋錯時第 3 步會被跳過。

| 步驟 | 對 Fridge 做了什麼 | 為什麼放在這個位置 |
|---|---|---|
| `ensureDefaultFridge()` | 本機沒有 `ShareZone` 的 Default 冰箱就建一座（預設清單、`.free`） | 必須同步完成：畫面組裝時要有冰箱可綁定，雲端同步是非同步的，不能指望它先完成 |
| `syncCloudToLocal()` | 依 record 的 zoneID 用 `ensureFridge` 建出缺少的冰箱，再用 `FridgeMetadata` 套用內容：別人冰箱的 `plan`、`createdAt`、標籤與位置清單 | 還原新裝置、重裝後的冰箱與接受分享後的共享冰箱。本機 `Fridge` 不同步，靠雲端 zone 反推重建 |
| `pushOwnedFridgeMetadata()` | 對每座冰箱 `upsert` `FridgeMetadata`，內容不同才寫入。Owner 寫完整欄位並建立缺少的 record，成員只補傳清單 | 讓空冰箱在雲端也有紀錄、補傳離線時沒傳上去的清單編輯、讓成員知道 Owner 的方案 |

### 設計重點
- **同一座冰箱只有一個 ID**：三者都靠 `Fridge.makeID`（`"<ownerName>|<zoneName>"`，自己一律是 `CKCurrentUserDefaultName`），所以不會重複建立。
- **同步在前、上傳在後**：先把雲端較新的清單套到本機，再上傳本機領先的內容，避免重裝後本機的預設值蓋掉雲端資料。
- **衝突規則**：清單用 `Fridge.listsUpdatedAt` 比較，最後寫入者勝；自己的 `plan` 不信雲端，成員的 `plan` 信 Owner。
- **雲端是備份與分享管道，不是唯一真相**：本機 `Fridge` 不同步，雲端只存 `FridgeMetadata`，兩邊透過這三步收斂。

### 同步後本機與雲端仍可能不同
`syncCloudToLocal` 是單向、有條件的套用，所以 `pushOwnedFridgeMetadata` 的比對不是多餘的：

- 本機有尚未上傳的清單編輯（離線或上傳失敗），`applyLists` 不會讓雲端蓋掉較新的本機
- 雲端沒有這筆 `FridgeMetadata`（新使用者的 Default 冰箱、空冰箱）
- 自己冰箱的 `plan` 本來就不從雲端套用
- 雲端 record 缺 `tags` / `locations`（舊版）時 `applyLists` 直接跳過
- 同步是增量的，沒有變動的 zone 不會重新套用

### 已知缺口
- 新使用者在同步完成前只看得到空的 Default 冰箱，同步完成後靠 `.cloudKitDataDidChange` 更新。
- 重裝後自己冰箱的 `plan` 不會從雲端還原，且 `pushOwnedFridgeMetadata` 可能把雲端的家庭版覆寫成 `free`，見 `可優化清單.md` 的 StoreKit 待辦。
