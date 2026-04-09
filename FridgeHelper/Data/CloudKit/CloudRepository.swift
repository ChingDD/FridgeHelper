//
//  CloudRepository.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/9.
//

import Foundation
import CloudKit

class CloudRepository: ItemRepositoryProtocol {

    let zoneMgr: ZoneManaging

    private let ckContainer: CKContainer

    private var database: CKDatabase {
        ckContainer.privateCloudDatabase
    }

    init(zoneMgr: ZoneManaging, containerIdentifier: String = "iCloud.FridgeHelper") {
        self.zoneMgr = zoneMgr
        self.ckContainer = CKContainer(identifier: containerIdentifier)
    }

    // MARK: - ItemRepositoryProtocol

    func fetch() async throws -> [Item] {
        try await zoneMgr.ensureZoneExists()
        let query = CKQuery(recordType: "Item", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: zoneMgr.zoneID)

        return matchResults.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return toItem(record)
        }
    }

    func add(item: Item) async throws {
        try await zoneMgr.ensureZoneExists()
        let record = toRecord(item)
        try await database.save(record)
    }

    func update(item: Item) async throws {
        let record = toRecord(item)
        try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }

    func delete(item: Item) async throws {
        let id = recordID(for: item)
        try await database.deleteRecord(withID: id)
    }

    // MARK: - Mapping

    private func recordID(for item: Item) -> CKRecord.ID {
        let name = item.timeStamp ?? UUID().uuidString
        return CKRecord.ID(recordName: name, zoneID: zoneMgr.zoneID)
    }

    private func toRecord(_ item: Item) -> CKRecord {
        let record = CKRecord(recordType: "Item", recordID: recordID(for: item))
        record["name"] = item.name
        record["quantity"] = item.number as CKRecordValue
        record["expiry"] = item.expiryDate as CKRecordValue
        record["store"] = item.storeCondition as CKRecordValue
        record["memo"] = item.memo as CKRecordValue?
        record["tag"] = item.tag as CKRecordValue?
        record["timestamp"] = item.timeStamp as CKRecordValue?

        if let imageData = item.image {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try? imageData.write(to: tempURL)
            record["image"] = CKAsset(fileURL: tempURL)
        }

        return record
    }

    private func toItem(_ record: CKRecord) -> Item {
        let name = record["name"] as? String ?? ""
        let number = (record["quantity"] as? Int64).map { Int($0) } ?? 0
        let expiryDate = record["expiry"] as? Date ?? Date()
        let storeCondition = (record["store"] as? Int64).map { Int($0) } ?? 0
        let memo = record["memo"] as? String
        let tag = record["tag"] as? String
        let timeStamp = record["timestamp"] as? String

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
            timeStamp: timeStamp
        )
    }
}
