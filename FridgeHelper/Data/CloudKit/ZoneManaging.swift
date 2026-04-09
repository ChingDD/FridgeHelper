//
//  ZoneManaging.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/9.
//

import Foundation
import CloudKit

protocol ZoneManaging {
    var zoneID: CKRecordZone.ID { get }
    func ensureZoneExists() async throws
}
