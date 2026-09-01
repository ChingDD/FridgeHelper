//
//  CloudRepository.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/9.
//

import Foundation
import CloudKit
import UIKit

class CloudRepository: ItemRepositoryProtocol {

    let zoneMgr: ZoneManaging

    private let ckContainer: CKContainer

    var privateDatabase: CKDatabase { ckContainer.privateCloudDatabase }
    var sharedDatabase: CKDatabase { ckContainer.sharedCloudDatabase }

    /// item 所屬冰箱決定要寫到哪個 database 的哪個 zone。
    /// fridgeID 本身就是字串化的 zoneID，直接還原即可，不需要查 Fridge
    private func route(for item: Item) -> (database: CKDatabase, zoneID: CKRecordZone.ID, isOwnZone: Bool) {
        let zoneID = Fridge.zoneID(from: item.fridgeID) ?? legacyZoneID(for: item)
        let isOwnZone = Fridge.isOwnZone(zoneID)
        return (isOwnZone ? privateDatabase : sharedDatabase, zoneID, isOwnZone)
    }

    /// fridgeID 尚未歸戶時的退路：沿用單一冰箱時代只看 zoneOwnerName 的判斷
    private func legacyZoneID(for item: Item) -> CKRecordZone.ID {
        guard let owner = item.zoneOwnerName, owner != CKCurrentUserDefaultName else {
            return zoneMgr.zoneID
        }
        return CKRecordZone.ID(zoneName: zoneMgr.zoneID.zoneName, ownerName: owner)
    }

    init(zoneMgr: ZoneManaging, containerIdentifier: String = "iCloud.FridgeHelper") {
        self.zoneMgr = zoneMgr
        self.ckContainer = CKContainer(identifier: containerIdentifier)
    }

    // MARK: - ItemRepositoryProtocol

    func fetch() async throws -> [Item] {
        try await zoneMgr.ensureZoneExists()
        let query = CKQuery(recordType: "Item", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneMgr.zoneID)

        return matchResults.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return ItemRecordMapper.item(from: record)
        }
    }

    /// 逐冰箱讀取一律走本機 SwiftData，雲端不提供這條路徑
    func fetch(fridgeID: String) async throws -> [Item] { [] }

    func count(fridgeID: String) async throws -> Int { 0 }

    func add(item: Item) async throws {
        let destination = route(for: item)
        // toRecord 必須在 await 前呼叫，確保在 caller 的 actor（MainActor）上讀取 @Model 屬性
        let (record, tempURL) = toRecord(item, in: destination.zoneID)
        defer { tempURL.map { try? FileManager.default.removeItem(at: $0) } }
        // 在別人的冰箱新增食材時，zone 早就由 Owner 建好，直接寫 sharedDB
        if destination.isOwnZone {
            try await zoneMgr.ensureZoneExists(destination.zoneID)
        }
        try await destination.database.save(record)
    }

    func update(item: Item) async throws {
        let destination = route(for: item)
        let (record, tempURL) = toRecord(item, in: destination.zoneID)
        defer { tempURL.map { try? FileManager.default.removeItem(at: $0) } }
        try await destination.database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }

    func delete(item: Item) async throws {
        let destination = route(for: item)
        try await destination.database.deleteRecord(withID: recordID(for: item, in: destination.zoneID))
    }

    // MARK: - Mapping

    private func recordID(for item: Item, in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        let name = item.timeStamp ?? UUID().uuidString
        return CKRecord.ID(recordName: name, zoneID: zoneID)
    }

    private func toRecord(_ item: Item, in zoneID: CKRecordZone.ID) -> (CKRecord, URL?) {
        let record = CKRecord(recordType: "Item", recordID: recordID(for: item, in: zoneID))
        let tempURL = ItemRecordMapper.populate(record, from: item)
        return (record, tempURL)
    }
}
