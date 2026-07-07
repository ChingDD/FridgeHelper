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
