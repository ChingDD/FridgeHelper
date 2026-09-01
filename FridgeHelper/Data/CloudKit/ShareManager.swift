//
//  ShareManager.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/9.
//

import Foundation
import CloudKit

enum ShareError: LocalizedError {
    case notOwner

    var errorDescription: String? {
        switch self {
        case .notOwner: return "只有冰箱的擁有者可以邀請成員。"
        }
    }
}

extension CKShare.Participant {
    /// 身分名稱：姓名 → email → 電話；都取不到回傳 nil
    var identityName: String? {
        let formattedName = userIdentity.nameComponents
            .map { PersonNameComponentsFormatter().string(from: $0) }
            .flatMap { $0.isEmpty ? nil : $0 }
        return formattedName
            ?? userIdentity.lookupInfo?.emailAddress
            ?? userIdentity.lookupInfo?.phoneNumber
    }

    /// 顯示用名稱，取不到身分時用泛稱
    var displayName: String { identityName ?? "成員" }
}

/// 一座冰箱的共享狀態。每座冰箱各自一個 CKShare，因此這個物件也綁定單一 zone
class ShareManager: SharingRepositoryProtocol {

    private let zoneID: CKRecordZone.ID
    /// 自己擁有的冰箱才能邀請或停止共享；別人的冰箱只能唯讀 sharedDB 上的 CKShare
    private let isOwnedByCurrentUser: Bool
    private let zoneMgr: ZoneManaging
    private let ckContainer: CKContainer

    private var privateDatabase: CKDatabase { ckContainer.privateCloudDatabase }
    private var sharedDatabase: CKDatabase { ckContainer.sharedCloudDatabase }

    init(fridge: Fridge, zoneMgr: ZoneManaging, containerIdentifier: String = "iCloud.FridgeHelper") {
        self.zoneID = fridge.zoneID
        self.isOwnedByCurrentUser = fridge.isOwnedByCurrentUser
        self.zoneMgr = zoneMgr
        self.ckContainer = CKContainer(identifier: containerIdentifier)
    }

    // MARK: - SharingRepositoryProtocol

    func fetchOrCreateShare() async throws -> (CKShare, CKContainer) {
        guard isOwnedByCurrentUser else { throw ShareError.notOwner }
        try await zoneMgr.ensureZoneExists(zoneID)

        if let existing = try await fetchExistingShare() {
            return (existing, ckContainer)
        }

        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "我的冰箱" as CKRecordValue

        try await privateDatabase.save(share)
        return (share, ckContainer)
    }

    func stopSharing() async throws {
        guard let share = try await fetchExistingShare() else { return }
        try await privateDatabase.deleteRecord(withID: share.recordID)
    }

    func fetchExistingShare() async throws -> CKShare? {
        guard isOwnedByCurrentUser else { return nil }
        return try await Self.fetchZoneWideShare(zoneID: zoneID, in: privateDatabase)
    }

    /// 只查這座冰箱自己的 zone。
    /// 舊版取 sharedDB 的 `zones.first`，加入兩座以上共享冰箱時會拿到別座的 share
    func fetchParticipatingShare() async throws -> CKShare? {
        guard !isOwnedByCurrentUser else { return nil }
        return try await Self.fetchZoneWideShare(zoneID: zoneID, in: sharedDatabase)
    }

    // MARK: - Zone-wide share 查詢

    /// zone-wide share 的 recordName 是固定值，不需要列舉 zone 就能直接取。
    /// zone 或 share 不存在都視為「沒有共享」
    static func fetchZoneWideShare(zoneID: CKRecordZone.ID, in database: CKDatabase) async throws -> CKShare? {
        let shareRecordID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        do {
            return try await database.record(for: shareRecordID) as? CKShare
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }
}
