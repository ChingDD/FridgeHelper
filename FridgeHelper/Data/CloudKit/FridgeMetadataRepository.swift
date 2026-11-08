//
//  FridgeMetadataRepository.swift
//  FridgeHelper
//
//  把「冰箱本身」寫進它的 Zone。
//
//  方案（plan）只有 Owner 會寫：成員的方案來源是自己的購買權益，
//  讓成員寫回去會把 Owner 的家庭版蓋成免費方案。
//  標籤與儲存位置清單則 Owner 與成員都能編輯，以 listsUpdatedAt 最後寫入者勝
//

import Foundation
import CloudKit

@MainActor
class FridgeMetadataRepository {

    private let zoneMgr: ZoneManaging
    private let ckContainer: CKContainer

    private var privateDatabase: CKDatabase { ckContainer.privateCloudDatabase }
    private var sharedDatabase: CKDatabase { ckContainer.sharedCloudDatabase }

    init(zoneMgr: ZoneManaging, containerIdentifier: String = "iCloud.FridgeHelper") {
        self.zoneMgr = zoneMgr
        self.ckContainer = CKContainer(identifier: containerIdentifier)
    }

    /// 把這座冰箱的資料寫進雲端。
    /// Owner 寫完整的 FridgeMetadata；成員只更新清單欄位，且 record 不存在時不建立
    /// （那是 Owner 的職責，成員建立會讓 plan 退回預設值）
    func upsert(for fridge: Fridge) async throws {
        let isOwner = fridge.isOwnedByCurrentUser
        let database = isOwner ? privateDatabase : sharedDatabase
        let zoneID = fridge.zoneID
        if isOwner { try await zoneMgr.ensureZoneExists(zoneID) }

        let recordID = FridgeMetadataRecordMapper.recordID(in: zoneID)
        let existing = try await fetchRecord(recordID, in: database)

        if let existing {
            let upToDate = isOwner
                ? FridgeMetadataRecordMapper.isUpToDate(existing, for: fridge)
                : FridgeMetadataRecordMapper.listsAreUpToDate(existing, for: fridge)
            if upToDate { return }
        } else if !isOwner {
            return
        }

        // 先讀再改：直接 new 一筆同 ID 的 record 覆蓋，會抹掉新版寫入、本版還不認識的欄位
        let record = existing ?? CKRecord(recordType: FridgeMetadataRecordMapper.recordType, recordID: recordID)
        if isOwner {
            FridgeMetadataRecordMapper.populate(record, from: fridge)
        } else {
            FridgeMetadataRecordMapper.populateLists(record, from: fridge)
        }

        do {
            try await database.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // 別台裝置剛好同時寫入：以 listsUpdatedAt 較新者為準，我方較新才重寫一次
            guard let server = error.serverRecord else { throw error }
            let serverUpdatedAt = server["listsUpdatedAt"] as? Date ?? .distantPast
            guard fridge.listsUpdatedAt > serverUpdatedAt else { return }
            FridgeMetadataRecordMapper.populateLists(server, from: fridge)
            try await database.save(server)
        }
    }

    private func fetchRecord(_ recordID: CKRecord.ID, in database: CKDatabase) async throws -> CKRecord? {
        do {
            return try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }
}
