//
//  ZoneManager.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/9.
//

import Foundation
import CloudKit

class ZoneManager: ZoneManaging {
    let zoneID: CKRecordZone.ID

    init(zoneName: String = "ShareZone") {
        self.zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    func ensureZoneExists() async throws {
        let database = CKContainer.default().privateCloudDatabase
        let zone = CKRecordZone(zoneID: zoneID)
        try await database.save(zone)
    }
}
