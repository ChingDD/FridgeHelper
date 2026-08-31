//
//  ZoneManager.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/9.
//

import Foundation
import CloudKit

class ZoneManager: ZoneManaging {
    /// Default 冰箱的 zone 名稱。多冰箱後新增的 zone 用 `Fridge_<UUID>`，這座沿用舊名不遷移
    static let defaultZoneName = "ShareZone"

    let zoneID: CKRecordZone.ID
    private let containerIdentifier: String

    init(zoneName: String = ZoneManager.defaultZoneName, containerIdentifier: String = "iCloud.FridgeHelper") {
        self.zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        self.containerIdentifier = containerIdentifier
    }

    func ensureZoneExists() async throws {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let zone = CKRecordZone(zoneID: zoneID)
        try await database.save(zone)
    }
}
