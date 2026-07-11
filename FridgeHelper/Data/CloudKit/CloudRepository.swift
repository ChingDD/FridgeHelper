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

    /// item 的 zoneOwnerName 非當前使用者 → 來自共享 zone → 走 sharedDB
    private func database(for item: Item) -> CKDatabase {
        guard let owner = item.zoneOwnerName, owner != CKCurrentUserDefaultName else {
            return privateDatabase
        }
        return sharedDatabase
    }

    /// 根據 item 的 zoneOwnerName 建立正確的 zone ID
    private func zoneID(for item: Item) -> CKRecordZone.ID {
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

    func add(item: Item) async throws {
        // 新增 item 預設寫入自己的 private zone，不需走 sharedDB
        // toRecord 必須在 await 前呼叫，確保在 caller 的 actor（MainActor）上讀取 @Model 屬性
        let (record, tempURL) = toRecord(item)
        defer { tempURL.map { try? FileManager.default.removeItem(at: $0) } }
        try await zoneMgr.ensureZoneExists()
        try await privateDatabase.save(record)
    }

    func update(item: Item) async throws {
        let (record, tempURL) = toRecord(item)
        defer { tempURL.map { try? FileManager.default.removeItem(at: $0) } }
        try await database(for: item).modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }

    func delete(item: Item) async throws {
        let id = recordID(for: item)
        try await database(for: item).deleteRecord(withID: id)
    }

    // MARK: - Mapping

    private func recordID(for item: Item) -> CKRecord.ID {
        let name = item.timeStamp ?? UUID().uuidString
        return CKRecord.ID(recordName: name, zoneID: zoneID(for: item))
    }

    private func toRecord(_ item: Item) -> (CKRecord, URL?) {
        let record = CKRecord(recordType: "Item", recordID: recordID(for: item))
        let tempURL = ItemRecordMapper.populate(record, from: item)
        return (record, tempURL)
    }
}
