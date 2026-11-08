//
//  DebugCloudReset.swift
//  FridgeHelper
//
//  僅 DEBUG 使用：清空目前登入 iCloud 帳號在這個 container 的資料。
//  - 刪除 privateDB 所有自訂 zone（含 Item、FridgeMetadata、CKShare）
//  - 離開 sharedDB 所有被分享的 zone（刪除 shared zone = 退出共享）
//  - 清除同步 token、選取中的冰箱、本機 SwiftData、已排程通知
//  Record Type（schema）屬於 container，不會被影響
//

#if DEBUG
import Foundation
import CloudKit
import SwiftData
import UserNotifications

enum DebugCloudReset {

    /// 回傳被刪除的 zone 數量（private, shared）
    @MainActor
    @discardableResult
    static func resetAll(
        modelContainer: ModelContainer,
        containerIdentifier: String = "iCloud.FridgeHelper"
    ) async throws -> (private: Int, shared: Int) {
        let container = CKContainer(identifier: containerIdentifier)

        let privateCount = try await deleteAllZones(in: container.privateCloudDatabase)
        let sharedCount = try await deleteAllZones(in: container.sharedCloudDatabase)

        clearSyncState()
        try clearLocalData(modelContainer)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        return (privateCount, sharedCount)
    }

    // MARK: - Cloud

    private static func deleteAllZones(in database: CKDatabase) async throws -> Int {
        let zones = try await database.allRecordZones()
        // 每個 database 都有不可刪的 _defaultZone，排除掉
        let zoneIDs = zones.map(\.zoneID).filter { $0.zoneName != CKRecordZone.ID.defaultZoneName }
        guard !zoneIDs.isEmpty else { return 0 }

        let result = try await database.modifyRecordZones(saving: [], deleting: zoneIDs)
        // 任何一座刪除失敗就丟出錯誤，避免誤以為已清乾淨
        for (_, deletion) in result.deleteResults {
            try deletion.get()
        }
        return zoneIDs.count
    }

    // MARK: - Local

    private static func clearSyncState() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("syncToken_") {
            defaults.removeObject(forKey: key)
        }
        SelectedFridgeStore.fridgeID = nil
    }

    @MainActor
    private static func clearLocalData(_ modelContainer: ModelContainer) throws {
        let context = modelContainer.mainContext
        try context.delete(model: Item.self)
        try context.delete(model: Fridge.self)
        try context.save()
    }
}
#endif
