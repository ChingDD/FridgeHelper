//
//  ShareManager.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/9.
//

import Foundation
import CloudKit

class ShareManager: SharingRepositoryProtocol {

    private let zoneMgr: ZoneManaging
    private let ckContainer: CKContainer

    private var database: CKDatabase {
        ckContainer.privateCloudDatabase
    }

    init(zoneMgr: ZoneManaging, containerIdentifier: String = "iCloud.FridgeHelper") {
        self.zoneMgr = zoneMgr
        self.ckContainer = CKContainer(identifier: containerIdentifier)
    }

    // MARK: - SharingRepositoryProtocol

    func fetchOrCreateShare() async throws -> (CKShare, CKContainer) {
        try await zoneMgr.ensureZoneExists()

        if let existing = try await fetchExistingShare() {
            return (existing, ckContainer)
        }

        let share = CKShare(recordZoneID: zoneMgr.zoneID)
        share[CKShare.SystemFieldKey.title] = "我的冰箱" as CKRecordValue

        try await database.save(share)
        return (share, ckContainer)
    }

    func stopSharing() async throws {
        guard let share = try await fetchExistingShare() else { return }
        try await database.deleteRecord(withID: share.recordID)
    }

    // MARK: - Private

    private func fetchExistingShare() async throws -> CKShare? {
        let shareRecordID = CKRecord.ID(
            recordName: CKRecordNameZoneWideShare,
            zoneID: zoneMgr.zoneID
        )
        do {
            let record = try await database.record(for: shareRecordID)
            return record as? CKShare
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }
}
