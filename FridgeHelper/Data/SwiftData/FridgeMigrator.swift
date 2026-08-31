//
//  FridgeMigrator.swift
//  FridgeHelper
//
//  階段 2A 一次性本地遷移：把單一冰箱時代的食材與清單歸戶到 Fridge
//

import Foundation
import SwiftData
import CloudKit

@MainActor
struct FridgeMigrator {

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    /// 以 `Item.fridgeID` 是否為空當作未遷移標記，天然冪等，可在每次啟動呼叫。
    ///
    /// 遷移建立的冰箱沿用舊有的標籤／儲存位置清單；之後新建或新加入的冰箱才用系統預設值。
    /// 舊的 UserDefaults 清單不刪除，等清單改由 Fridge 提供後再處理
    func migrateIfNeeded() throws {
        let legacyTags = UserDefaults.standard.stringArray(forKey: FridgeListDefaults.legacyTagsKey) ?? FridgeListDefaults.tags
        let legacyLocations = UserDefaults.standard.stringArray(forKey: FridgeListDefaults.legacyLocationsKey) ?? FridgeListDefaults.locations

        // 先把既有 Fridge 讀進字典：同一批尚未 save 的 insert 不保證能被後續 fetch 看見，
        // 同一位共享者的食材散在多處時會重複建立同一座冰箱
        var fridgesByID = try context.fetch(FetchDescriptor<Fridge>())
            .reduce(into: [String: Fridge]()) { $0[$1.fridgeID] = $1 }

        func fridgeID(ownerName: String?, name: String) -> String {
            // 舊有 shared Item 只存了 zoneOwnerName、沒有 zoneName。
            // 舊版本來就只支援單一 Zone，因此可安全假設 zoneName 就是 Default 冰箱的 ShareZone
            let id = Fridge.makeID(zoneName: ZoneManager.defaultZoneName, ownerName: ownerName)
            if let existing = fridgesByID[id] { return existing.fridgeID }
            let fridge = Fridge(
                zoneName: ZoneManager.defaultZoneName,
                ownerName: ownerName,
                name: name,
                tags: legacyTags,
                locations: legacyLocations
            )
            context.insert(fridge)
            fridgesByID[id] = fridge
            return fridge.fridgeID
        }

        // 即使一筆食材都沒有也要建立 Default 冰箱，後續組裝需要有冰箱可綁定
        let defaultFridgeID = fridgeID(ownerName: nil, name: "我的冰箱")

        let unassigned = try context.fetch(
            FetchDescriptor<Item>(predicate: #Predicate { $0.fridgeID == "" })
        )
        for item in unassigned {
            let owner = Fridge.normalizedOwnerName(item.zoneOwnerName)
            item.fridgeID = owner == CKCurrentUserDefaultName
                ? defaultFridgeID
                : fridgeID(ownerName: owner, name: "共享的冰箱")
        }

        if context.hasChanges {
            try context.save()
        }
    }
}
