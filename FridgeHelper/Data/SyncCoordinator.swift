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
import SwiftData

struct CloudItemChange {
    let itemName: String
    let updatedByName: String?
}

/// change token 的 UserDefaults key 產生器
///
/// key 必須同時包含 database scope、ownerName 與 zoneName。
/// 不同 Owner 的 zone 可能同名（例如爸爸與媽媽的 zone 都叫 ShareZone），
/// 只用 zoneName 會讓兩座 zone 共用同一個 token 而互相覆蓋。
enum SyncTokenKey {
    static let privateDatabase = "syncToken_privateDB"
    static let sharedDatabase = "syncToken_sharedDB"

    static func zone(_ zoneID: CKRecordZone.ID, scope: CKDatabase.Scope) -> String {
        "syncToken_\(name(for: scope))_\(zoneID.ownerName)_\(zoneID.zoneName)"
    }

    private static func name(for scope: CKDatabase.Scope) -> String {
        switch scope {
        case .public: return "public"
        case .private: return "private"
        case .shared: return "shared"
        @unknown default: return "unknown"
        }
    }
}

@MainActor
class SyncCoordinator {

    private let localRepository: ItemRepositoryProtocol
    private let ckContainer: CKContainer
    private let modelContainer: ModelContainer

    private var privateDatabase: CKDatabase { ckContainer.privateCloudDatabase }
    private var sharedDatabase: CKDatabase { ckContainer.sharedCloudDatabase }

    init(
        localRepository: ItemRepositoryProtocol,
        modelContainer: ModelContainer,
        containerIdentifier: String = "iCloud.FridgeHelper"
    ) {
        self.localRepository = localRepository
        self.modelContainer = modelContainer
        self.ckContainer = CKContainer(identifier: containerIdentifier)
    }

    // MARK: - Public

    /// app 啟動 / 收到 silent push 時呼叫
    func fetchChanges() async throws -> [CloudItemChange] {
        let privateChanges = try await fetchPrivateChanges()
        let sharedChanges = try await fetchSharedChanges()
        return privateChanges + sharedChanges
    }

    // MARK: - Private DB（自己擁有的所有冰箱 zone）

    private func fetchPrivateChanges() async throws -> [CloudItemChange] {
        try await fetchChanges(from: privateDatabase,
                               scope: .private,
                               databaseTokenKey: SyncTokenKey.privateDatabase)
    }

    // MARK: - Shared DB（被邀請進來的 zones）

    private func fetchSharedChanges() async throws -> [CloudItemChange] {
        try await fetchChanges(from: sharedDatabase,
                               scope: .shared,
                               databaseTokenKey: SyncTokenKey.sharedDatabase)
    }

    /// 先問 database 有哪些 zone 變動，再逐 zone 抓 record 差異。
    ///
    /// private 與 shared 的流程完全相同，差別只在 database 與 token 的 scope。
    /// private 端不能再只同步固定那一座 zone：多冰箱後自己就有多個 private zone
    private func fetchChanges(
        from database: CKDatabase,
        scope: CKDatabase.Scope,
        databaseTokenKey: String
    ) async throws -> [CloudItemChange] {

        let savedDBToken = loadToken(forKey: databaseTokenKey)
        var itemChanges: [CloudItemChange] = []

        // Step 1：找出有哪些 zone 發生變動
        let (changedZoneIDs, deletedZoneIDs, newDBToken) = try await fetchDatabaseChanges(
            from: database,
            token: savedDBToken
        )

        // Step 2：對每個變動的 zone 抓 record 差異
        for zoneID in changedZoneIDs {
            let zoneTokenKey = SyncTokenKey.zone(zoneID, scope: scope)
            let savedZoneToken = loadToken(forKey: zoneTokenKey)

            let (changed, deleted, newZoneToken) = try await fetchZoneChanges(
                from: database,
                zoneID: zoneID,
                token: savedZoneToken
            )

            try await applyChanges(changed: changed, deleted: deleted)
            // 只有食材變動需要通知使用者，FridgeMetadata 的變動不必打擾
            itemChanges.append(contentsOf: changed.filter { $0.recordType == "Item" }.map(toCloudItemChange))

            if let token = newZoneToken {
                saveToken(token, forKey: zoneTokenKey)
            }
        }

        // Step 3：被刪除的 zone（對方撤銷共享、或自己在別台裝置刪掉冰箱）→ 清除 token
        for zoneID in deletedZoneIDs {
            UserDefaults.standard.removeObject(forKey: SyncTokenKey.zone(zoneID, scope: scope))
        }

        if let token = newDBToken {
            saveToken(token, forKey: databaseTokenKey)
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
                // 只處理自己認得的型別，過濾 CKShare 等其他類型避免產生空白資料
                guard let record = try? result.get() else { return }
                if record.recordType == "Item" || record.recordType == FridgeMetadataRecordMapper.recordType {
                    changedRecords.append(record)
                }
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
            // 冰箱本身必須先落地：食材要掛在冰箱上，
            // 而 FridgeMetadata 是空冰箱在雲端唯一會出現的 record
            let fridge = try await ensureFridge(for: record.recordID.zoneID)
            guard record.recordType == "Item" else {
                applyFridgeMetadata(record, to: fridge)
                continue
            }

            let incoming = ItemRecordMapper.item(from: record)
            let existingItems = try await localRepository.fetch()
            if let existing = existingItems.first(where: { $0.timeStamp == incoming.timeStamp }) {
                existing.fridgeID = incoming.fridgeID
                existing.name = incoming.name
                existing.number = incoming.number
                existing.unit = incoming.unit
                existing.expiryDate = incoming.expiryDate
                existing.storeCondition = incoming.storeCondition
                existing.storeLocation = incoming.storeLocation
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

    // MARK: - Fridge 歸戶

    /// record 所在 zone 對應的 Fridge，不存在就建立。
    /// 這條路徑涵蓋新裝置與重新安裝：本機 Fridge 沒有同步，靠 record 的 zoneID 反推重建。
    /// 新建的冰箱使用系統預設清單
    private func ensureFridge(for zoneID: CKRecordZone.ID) async throws -> Fridge {
        let fridgeID = Fridge.makeID(zoneName: zoneID.zoneName, ownerName: zoneID.ownerName)
        var descriptor = FetchDescriptor<Fridge>(predicate: #Predicate { $0.fridgeID == fridgeID })
        descriptor.fetchLimit = 1

        let context = modelContainer.mainContext
        if let existing = try context.fetch(descriptor).first { return existing }

        let name: String
        if Fridge.isOwnZone(zoneID) {
            name = FridgeDefaultName.own
        } else {
            name = FridgeDefaultName.shared(from: await sharedZoneOwnerName(of: zoneID))
        }

        let fridge = Fridge(
            zoneName: zoneID.zoneName,
            ownerName: zoneID.ownerName,
            name: name,
            tags: FridgeListDefaults.tags,
            locations: FridgeListDefaults.locations
        )
        context.insert(fridge)
        try context.save()
        return fridge
    }

    /// 共享冰箱的分享者名稱，用來當初始冰箱名稱。取不到就讓名稱退回泛用值，不影響同步
    private func sharedZoneOwnerName(of zoneID: CKRecordZone.ID) async -> String? {
        let share = try? await ShareManager.fetchZoneWideShare(zoneID: zoneID, in: sharedDatabase)
        return share?.owner.identityName
    }

    /// 把 Zone 裡的冰箱資料套用到本機 Fridge。
    ///
    /// 方案只套用在別人的冰箱：自己的冰箱以本機購買權益為準，
    /// 讓雲端上尚未更新的舊值蓋回來會把自己降級。
    /// `updatedAt` 也不套用，本機那個欄位記的是本機資料（例如標籤清單）最後變動時間
    private func applyFridgeMetadata(_ record: CKRecord, to fridge: Fridge) {
        let snapshot = FridgeMetadataRecordMapper.snapshot(from: record)
        if !fridge.isOwnedByCurrentUser {
            fridge.plan = snapshot.plan
        }
        fridge.createdAt = snapshot.createdAt
        try? modelContainer.mainContext.save()
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

    private func toCloudItemChange(_ record: CKRecord) -> CloudItemChange {
        CloudItemChange(
            itemName: record["name"] as? String ?? "物品",
            updatedByName: record["updatedByName"] as? String
        )
    }
}
