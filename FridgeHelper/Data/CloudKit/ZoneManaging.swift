//
//  ZoneManaging.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/9.
//

import Foundation
import CloudKit

protocol ZoneManaging {
    /// Default 冰箱的 zone。未指定冰箱的路徑（例如 App 啟動時的初始化）用它
    var zoneID: CKRecordZone.ID { get }
    /// 確保指定 zone 存在，不存在就建立。
    /// 只對自己的 zone 有意義：共享冰箱的 zone 由 Owner 建立，participant 沒有權限也不需要建
    func ensureZoneExists(_ zoneID: CKRecordZone.ID) async throws
}

extension ZoneManaging {
    func ensureZoneExists() async throws {
        try await ensureZoneExists(zoneID)
    }
}
