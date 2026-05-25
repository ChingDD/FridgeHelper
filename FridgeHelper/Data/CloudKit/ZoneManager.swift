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
    private let containerIdentifier: String

    init(zoneName: String = "ShareZone", containerIdentifier: String = "iCloud.FridgeHelper") {
        self.zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        self.containerIdentifier = containerIdentifier
    }

    func ensureZoneExists() async throws {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let zone = CKRecordZone(zoneID: zoneID)
        try await database.save(zone)
    }
}
