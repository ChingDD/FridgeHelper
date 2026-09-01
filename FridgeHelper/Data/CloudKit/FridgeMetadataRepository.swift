//
//  FridgeMetadataRepository.swift
//  FridgeHelper
//
//  把「冰箱本身」寫進它的 Zone。
//
//  只有 Owner 會寫：成員的方案來源是自己的購買權益，
//  讓成員寫回去會把 Owner 的家庭版蓋成免費方案
//

import Foundation
import CloudKit

@MainActor
class FridgeMetadataRepository {

    private let zoneMgr: ZoneManaging
    private let ckContainer: CKContainer

    private var privateDatabase: CKDatabase { ckContainer.privateCloudDatabase }

    init(zoneMgr: ZoneManaging, containerIdentifier: String = "iCloud.FridgeHelper") {
        self.zoneMgr = zoneMgr
        self.ckContainer = CKContainer(identifier: containerIdentifier)
    }

    /// 建立或更新這座冰箱的 FridgeMetadata。不是自己擁有的冰箱直接略過
    func upsert(for fridge: Fridge) async throws {
        guard fridge.isOwnedByCurrentUser else { return }

        let zoneID = fridge.zoneID
        try await zoneMgr.ensureZoneExists(zoneID)

        let recordID = FridgeMetadataRecordMapper.recordID(in: zoneID)
        let existing = try await fetchRecord(recordID)
        if let existing, FridgeMetadataRecordMapper.isUpToDate(existing, for: fridge) { return }

        // 先讀再改：直接 new 一筆同 ID 的 record 覆蓋，會抹掉新版寫入、本版還不認識的欄位
        let record = existing ?? CKRecord(recordType: FridgeMetadataRecordMapper.recordType, recordID: recordID)
        FridgeMetadataRecordMapper.populate(record, from: fridge)
        try await privateDatabase.save(record)
    }

    private func fetchRecord(_ recordID: CKRecord.ID) async throws -> CKRecord? {
        do {
            return try await privateDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }
}
