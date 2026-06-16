# FridgeHelper Enhancements

## [Enhancement] 回到前景時觸發 CloudKit Sync

**位置**：`SceneDelegate.swift` → `sceneWillEnterForeground(_:)`

**說明**：
目前 CloudKit sync 只在 App 啟動及收到 silent push 時觸發。
使用者長時間將 App 置於背景後切回，若這段期間沒有收到 push，資料不會自動更新。

**實作方向**：
```swift
func sceneWillEnterForeground(_ scene: UIScene) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
    Task {
        try? await appDelegate.syncCloudToLocal()
    }
}
```

---

## [Enhancement] 停止分享 UI 入口（stopSharing）

**位置**：`MainTableViewController.swift` → `shareTapped()` 附近 / 分享相關 extension

**說明**：
`ShareManager.stopSharing()` 已實作，但目前沒有任何 UI 可以呼叫它。
Owner 無法透過 App 撤銷共享。

**實作方向**：
- 在 `shareTapped()` 中，若已有現成的 `CKShare`（表示目前正在分享），可在 `UICloudSharingController` 或另一個 Alert 中加入「停止分享」選項
- 呼叫 `shareManager?.stopSharing()` 並在完成後更新 UI

```swift
// 範例：長按或額外按鈕
@objc private func stopSharingTapped() {
    Task {
        try? await shareManager?.stopSharing()
        // 通知 UI 更新（例如隱藏分享按鈕或顯示 alert）
    }
}
```
