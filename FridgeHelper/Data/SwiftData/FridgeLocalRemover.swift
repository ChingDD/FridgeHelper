//
//  FridgeLocalRemover.swift
//  FridgeHelper
//
//  移除一座冰箱在本機的所有資料。兩個情境共用：
//  - 使用者刪除自己的冰箱／離開共享冰箱
//  - 同步時發現 zone 已被刪除（別台裝置刪除、或對方撤銷共享）
//

import Foundation
import CloudKit
import SwiftData

@MainActor
struct FridgeLocalRemover {

    private let container: ModelContainer
    /// 清除食材已排程的通知；由呼叫端注入，避免資料層依賴 AppDelegate
    private let removeNotifications: (Item) -> Void

    init(container: ModelContainer, removeNotifications: @escaping (Item) -> Void) {
        self.container = container
        self.removeNotifications = removeNotifications
    }

    /// 刪除該冰箱的食材、通知、同步 token 與 Fridge 本身；不存在時什麼都不做
    func remove(fridgeID: String) throws {
        let context = container.mainContext

        let items = try context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.fridgeID == fridgeID }))
        items.forEach(removeNotifications)
        for item in items { context.delete(item) }

        var descriptor = FetchDescriptor<Fridge>(predicate: #Predicate { $0.fridgeID == fridgeID })
        descriptor.fetchLimit = 1
        if let fridge = try context.fetch(descriptor).first {
            let scope: CKDatabase.Scope = fridge.isOwnedByCurrentUser ? .private : .shared
            UserDefaults.standard.removeObject(forKey: SyncTokenKey.zone(fridge.zoneID, scope: scope))
            context.delete(fridge)
        }

        if SelectedFridgeStore.fridgeID == fridgeID {
            SelectedFridgeStore.fridgeID = nil
        }
        try context.save()
    }
}
