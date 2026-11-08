//
//  FridgeMigrator.swift
//  FridgeHelper
//
//  啟動時確保本機一定有 Default 冰箱
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

    /// 本機沒有 Default 冰箱（自己的 `ShareZone`）就建立一座，已存在則什麼都不做，可在每次啟動呼叫。
    ///
    /// 全新安裝在雲端有 record 之前，`SyncCoordinator.ensureFridge` 不會建立任何冰箱，
    /// 這裡確保後續組裝一定有冰箱可綁定。清單使用系統預設值
    func ensureDefaultFridge() throws {
        let id = Fridge.makeID(zoneName: ZoneManager.defaultZoneName, ownerName: nil)
        var descriptor = FetchDescriptor<Fridge>(predicate: #Predicate { $0.fridgeID == id })
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        context.insert(
            Fridge(
                zoneName: ZoneManager.defaultZoneName,
                ownerName: nil,
                name: FridgeDefaultName.own,
                tags: FridgeListDefaults.tags,
                locations: FridgeListDefaults.locations
            )
        )
        try context.save()
    }
}
