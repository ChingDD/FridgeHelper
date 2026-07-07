//
//  SyncCoordinator.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/9.
//
//  職責：雲端 → 本地同步（change token 差異同步）
//  - 不處理使用者 CRUD，只負責把 CloudKit 的變動套用到 SwiftData

import Foundation
import CloudKit

struct CloudItemChange {
    let itemName: String
    let updatedByName: String?
}

@MainActor
class SyncCoordinator {

    private let localRepository: ItemRepositoryProtocol
    private let zoneMgr: ZoneManaging
    private let ckContainer: CKContainer

    private var privateDatabase: CKDatabase { ckContainer.privateCloudDatabase }
    private var sharedDatabase: CKDatabase { ckContainer.sharedCloudDatabase }

    init(
        localRepository: ItemRepositoryProtocol,
        zoneMgr: ZoneManaging,
        containerIdentifier: String = "iCloud.FridgeHelper"
    ) {
        self.localRepository = localRepository
        self.zoneMgr = zoneMgr
        self.ckContainer = CKContainer(identifier: containerIdentifier)
    }

    // MARK: - Public

    /// app 啟動 / 收到 silent push 時呼叫
    func fetchChanges() async throws -> [CloudItemChange] {
        let privateChanges = try await fetchPrivateChanges()
        let sharedChanges = try await fetchSharedChanges()
        return privateChanges + sharedChanges
    }

    // MARK: - Private DB（自己的 ShareZone）

    private func fetchPrivateChanges() async throws -> [CloudItemChange] {
        let tokenKey = "syncToken_private_\(zoneMgr.zoneID.zoneName)"
        let savedToken = loadToken(forKey: tokenKey)

        let (changed, deleted, newToken) = try await fetchZoneChanges(
            from: privateDatabase,
            zoneID: zoneMgr.zoneID,
            token: savedToken
        )

        try await applyChanges(changed: changed, deleted: deleted)

        if let token = newToken {
            saveToken(token, forKey: tokenKey)
        }

        return changed.map(toCloudItemChange)
    }

    // MARK: - Shared DB（被邀請進來的 zones）

    private func fetchSharedChanges() async throws -> [CloudItemChange] {
        let dbTokenKey = "syncToken_sharedDB"
        let savedDBToken = loadToken(forKey: dbTokenKey)
        var itemChanges: [CloudItemChange] = []

        // Step 1：找出 sharedDB 中有哪些 zone 發生變動
        let (changedZoneIDs, deletedZoneIDs, newDBToken) = try await fetchDatabaseChanges(
            from: sharedDatabase,
            token: savedDBToken
        )

        // Step 2：對每個變動的 zone 抓 record 差異
        for zoneID in changedZoneIDs {
            let zoneTokenKey = "syncToken_sharedZone_\(zoneID.zoneName)"
            let savedZoneToken = loadToken(forKey: zoneTokenKey)

            let (changed, deleted, newZoneToken) = try await fetchZoneChanges(
                from: sharedDatabase,
                zoneID: zoneID,
                token: savedZoneToken
            )

            try await applyChanges(changed: changed, deleted: deleted)
            itemChanges.append(contentsOf: changed.map(toCloudItemChange))

            if let token = newZoneToken {
                saveToken(token, forKey: zoneTokenKey)
            }
        }

        // Step 3：被刪除的 zone（對方撤銷共享）→ 清除 token
        for zoneID in deletedZoneIDs {
            UserDefaults.standard.removeObject(forKey: "syncToken_sharedZone_\(zoneID.zoneName)")
        }

        if let token = newDBToken {
            saveToken(token, forKey: dbTokenKey)
        }

        return itemChanges
    }

    // MARK: - CloudKit Operations

    private func fetchDatabaseChanges(
        from database: CKDatabase,
        token: CKServerChangeToken?
    ) async throws -> (changedZoneIDs: [CKRecordZone.ID], deletedZoneIDs: [CKRecordZone.ID], newToken: CKServerChangeToken?) {

        try await withCheckedThrowingContinuation { continuation in
            var changedZoneIDs: [CKRecordZone.ID] = []
            var deletedZoneIDs: [CKRecordZone.ID] = []
            var newToken: CKServerChangeToken?

            let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: token)

            operation.recordZoneWithIDChangedBlock = { changedZoneIDs.append($0) }
            operation.recordZoneWithIDWasDeletedBlock = { deletedZoneIDs.append($0) }
            operation.changeTokenUpdatedBlock = { newToken = $0 }

            operation.fetchDatabaseChangesResultBlock = { result in
                switch result {
                case .success(let (serverToken, _)):
                    newToken = serverToken
                    continuation.resume(returning: (changedZoneIDs, deletedZoneIDs, newToken))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func fetchZoneChanges(
        from database: CKDatabase,
        zoneID: CKRecordZone.ID,
        token: CKServerChangeToken?
    ) async throws -> (changed: [CKRecord], deleted: [CKRecord.ID], newToken: CKServerChangeToken?) {

        // 使用 withCheckedThrowingContinuation 將基於回呼 (Callback) 的 CloudKit 異步操作轉換為 Swift 的 async/await 風格
        try await withCheckedThrowingContinuation { continuation in
            // 用於儲存本次同步抓取到的所有變動（新增或修改）Record
            var changedRecords: [CKRecord] = []
            // 用於儲存本次同步中被刪除的 Record ID
            var deletedRecordIDs: [CKRecord.ID] = []
            // 本次操作結束後，由雲端回傳的最新變動權標 (Change Token)
            var newToken: CKServerChangeToken?

            // 建立區域同步的配置設定 (Zone Configuration)
            var config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            // 設定上一次同步留下的權標，雲端將只回傳「在那之後」的差異資料（增量同步）
            config.previousServerChangeToken = token

            // 建立「抓取區域變動」的操作物件，指定要同步的區域 ID 與對應的配置
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )

            // 當有資料發生變更（新增或更新）時，雲端會透過此閉包回傳 Record 內容
            operation.recordWasChangedBlock = { _, result in
                // 只處理 Item record，過濾 CKShare 等其他類型避免產生空白 Item
                if let record = try? result.get(), record.recordType == "Item" { changedRecords.append(record) }
            }

            // 當有資料被刪除時，雲端會透過此閉包回傳該 Record 的 ID
            operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                guard recordType == "Item" else { return }
                deletedRecordIDs.append(recordID)
            }

            // 當特定區域 (Zone) 的抓取階段性完成時，會回傳該區域最新的 Server Change Token
            operation.recordZoneFetchResultBlock = { _, result in
                // 若成功取得結果，則更新 newToken 以便存儲，供下次增量同步使用
                if case .success(let (serverToken, _, _)) = result { newToken = serverToken }
            }

            // 當整個操作（包含所有指定區域）執行完畢時的最終回呼
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    // 操作成功，將收集到的變更陣列、刪除清單及新權標回傳給呼叫端
                    continuation.resume(returning: (changedRecords, deletedRecordIDs, newToken))
                case .failure(let error):
                    // 操作失敗（例如網路問題），將錯誤拋出給 async/await 流程
                    continuation.resume(throwing: error)
                }
            }

            // 將配置好的操作任務加入指定的資料庫（私有或共享）中執行
            database.add(operation)
        }
    }

    // MARK: - Apply to Local（SwiftData）

    private func applyChanges(changed: [CKRecord], deleted: [CKRecord.ID]) async throws {
        // 每筆寫入前重新查詢本地，不跨 await 沿用同一份清單快照，
        // 避免套用期間本地已增刪時操作到過時的物件參考
        for record in changed {
            let incoming = toItem(record)
            let existingItems = try await localRepository.fetch()
            if let existing = existingItems.first(where: { $0.timeStamp == incoming.timeStamp }) {
                existing.name = incoming.name
                existing.number = incoming.number
                existing.expiryDate = incoming.expiryDate
                existing.storeCondition = incoming.storeCondition
                existing.memo = incoming.memo
                existing.tag = incoming.tag
                existing.image = incoming.image
                existing.updatedByName = incoming.updatedByName
                try await localRepository.update(item: existing)
            } else {
                try await localRepository.add(item: incoming)
            }
        }

        for recordID in deleted {
            let existingItems = try await localRepository.fetch()
            if let item = existingItems.first(where: { $0.timeStamp == recordID.recordName }) {
                try await localRepository.delete(item: item)
            }
        }
    }

    // MARK: - Token Persistence

    private func loadToken(forKey key: String) -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func saveToken(_ token: CKServerChangeToken, forKey key: String) {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Mapping（CKRecord → Item）

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

    private func toCloudItemChange(_ record: CKRecord) -> CloudItemChange {
        CloudItemChange(
            itemName: record["name"] as? String ?? "物品",
            updatedByName: record["updatedByName"] as? String
        )
    }
}
