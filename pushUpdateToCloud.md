# pushUpdateToCloud 運作筆記

`CompositeRepository.pushUpdateToCloud(_:)` 的運作概念，方便日後回顧。

## 解決什麼問題？

使用者**連續快速點擊**同一個 item 的數量（例如 1 連點到 5），`update(item:)` 會在短時間被呼叫多次。若每次都直接發一個 CloudKit 請求，會有兩個問題：

1. **請求風暴**：5 次點擊 = 5 個網路請求。
2. **舊值蓋新值（race condition）**：網路完成順序無法保證，可能「數量=3」比「數量=5」晚到雲端，導致雲端最後停在舊值。

解法：**single-flight（單飛）+ coalescing（請求合併）**。同一個 item 同時最多只有一個上傳在飛，飛行期間的變更用 dirty 標記合併，結束後補傳一次最新狀態。

## 兩個關鍵資料結構

```swift
private var uploadTasks: [String: Task<Void, Never>] = [:]  // 每個 item 目前在飛的上傳任務
private var dirtyKeys: Set<String> = []                     // 飛行期間又被改、需補傳的 item
```

- **key** = `item.timeStamp`（item 唯一識別）。
- **`uploadTasks[key]`**：代表「這個 item 現在有一個上傳正在進行中」（在飛旗標）。
- **`dirtyKeys`**：**髒標記**——「記憶體裡的值比雲端正在傳的值更新，收工後要補傳一次」。

## 程式碼

```swift
private func pushUpdateToCloud(_ item: Item) {
    let key = item.timeStamp ?? ""

    // ① 已有上傳在飛 → 不另開請求，只打髒標記後返回
    guard uploadTasks[key] == nil else {
        dirtyKeys.insert(key)
        return
    }

    // ② 沒有在飛的上傳 → 開新任務
    uploadTasks[key] = Task {
        repeat {
            dirtyKeys.remove(key)                    // ③ 清髒標記，準備傳目前最新狀態
            do {
                try await cloud.update(item: item)   // ④ toRecord 讀 item「當下」最新值
            } catch {
                printInfo("Cloud Update Failed: \(error)")
            }
        } while dirtyKeys.contains(key)              // ⑤ 飛行期間又被改髒 → 再傳一次
        uploadTasks[key] = nil                       // ⑥ 收工，清在飛旗標
    }
}
```

**關鍵（④）**：`item` 是 reference type（class），`cloud.update` 內 `toRecord` 讀的是 `item` **當下最新屬性值**，不是快照。所以補傳時自然夾帶到最新值，不需保存多份快照。

## 流程圖

```
update(item:) 被呼叫
        │
        ▼
  uploadTasks[key] 有值嗎？
        │
   ┌────┴─────────────────────────┐
   │有（在飛）                     │無
   ▼                              ▼
dirtyKeys.insert(key)        開 Task（single-flight）
return，不發請求                    │
                                   ▼
                          ┌──► dirtyKeys.remove(key)
                          │         │
                          │         ▼
                          │   await cloud.update(item)  ← 讀當下最新值
                          │         │
                          │         ▼
                          │   dirtyKeys.contains(key)?
                          │    │yes           │no
                          └────┘              ▼
                          （補傳一次）   uploadTasks[key] = nil（收工）
```

## 情境：連點數量 5 次

```
點擊1 → update → local 寫入 → pushUpdateToCloud
                                uploadTasks[key] 空 → 開 Task，開始上傳「值1」

點擊2 → update → local 寫入 → pushUpdateToCloud
                                uploadTasks[key] 已存在 → dirtyKeys.insert(key)，返回 ★不發請求
點擊3 → 同上（Set 去重）★不發請求
點擊4 → 同上          ★不發請求
點擊5 → 同上，此時 item.quantity 已是 5 ★不發請求

──── 第一次上傳「值1」完成 ────
   while: dirtyKeys.contains(key) == true → 進下一圈
   remove(key) → 再上傳一次，讀 item 當下值 = 5 ✅ 保證最終落地是最新值

   第二次上傳完成，dirtyKeys 已無 key → while 結束 → uploadTasks[key] = nil
```

**結果**：5 次點擊 → 最多只發 **2 次**請求（第一次 + 補傳一次），雲端最終值保證是 `5`。

## delete 如何配合

```swift
func delete(item: Item) async throws {
    let key = item.timeStamp ?? ""
    try await local.delete(item: item)
    dirtyKeys.remove(key)       // 取消尚未補傳的更新，避免刪除後 record 在雲端被復活
    let pending = uploadTasks[key]
    Task {
        await pending?.value    // 等在飛的上傳結束，確保 delete 最後到達
        try? await cloud.delete(item: item)
    }
}
```

- `dirtyKeys.remove(key)`：不清掉的話 `while dirtyKeys.contains(key)` 會再補傳一次，把剛刪掉的 record **在雲端復活**。
- `await pending?.value`：確保 delete 一定在 update **之後**才送到雲端，否則可能刪完又被 update 建回來（殭屍 record）。

## 一句話總結

| 元素 | 角色 |
|------|------|
| `uploadTasks[key]` | 「在飛」旗標——保證同一 item 同時只有一個上傳 |
| `dirtyKeys` | 「髒標記」——記錄飛行期間又被改、需收工後補傳 |
| `repeat...while` | 補傳迴圈——只要還髒就再傳一次，直到雲端追上最新值 |
| `item` 為 reference type | 補傳時自動讀到最新值，無需保存多份快照 |

典型的 **coalescing + single-flight** 模式：把「連續多次寫入」壓縮成「最多兩次網路請求」，同時用髒標記保證**最終一致性**——最後落地雲端的一定是記憶體裡的最新狀態。
