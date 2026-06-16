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
            return toItem(record)
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
        record["name"] = item.name
        record["quantity"] = item.number as CKRecordValue
        record["expiry"] = item.expiryDate as CKRecordValue
        record["store"] = item.storeCondition as CKRecordValue
        record["memo"] = item.memo as CKRecordValue?
        record["tag"] = item.tag as CKRecordValue?
        record["timestamp"] = item.timeStamp as CKRecordValue?
        record["updatedByName"] = UIDevice.current.name as CKRecordValue

        var tempURL: URL? = nil
        if let imageData = item.image {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? imageData.write(to: url)
            record["image"] = CKAsset(fileURL: url)
            tempURL = url
        }

        return (record, tempURL)
    }

    private func toItem(_ record: CKRecord) -> Item {
        let name = record["name"] as? String ?? ""
        let number = (record["quantity"] as? Int64).map { Int($0) } ?? 0
        let expiryDate = record["expiry"] as? Date ?? Date()
        let storeCondition = (record["store"] as? Int64).map { Int($0) } ?? 0
        let memo = record["memo"] as? String
        let tag = record["tag"] as? String
        let timeStamp = record["timestamp"] as? String
        let zoneOwnerName = record.recordID.zoneID.ownerName
        let updatedByName = record["updatedByName"] as? String

        var imageData: Data? = nil
        if let asset = record["image"] as? CKAsset, let url = asset.fileURL {
            imageData = try? Data(contentsOf: url)
        }

        return Item(
            name: name,
            number: number,
            expiryDate: expiryDate,
            storeCondition: storeCondition,
            memo: memo,
            tag: tag,
            image: imageData,
            timeStamp: timeStamp,
            zoneOwnerName: zoneOwnerName,
            updatedByName: updatedByName
        )
    }
}
