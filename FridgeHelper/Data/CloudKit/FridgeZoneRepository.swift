//
//  FridgeZoneRepository.swift
//  FridgeHelper
//
//  刪除冰箱在雲端的 zone。
//  Owner 刪除自己 privateDB 的 zone（連同 CKShare，所有成員失去存取）；
//  成員刪除 sharedDB 的 zone 等同離開共享，不影響 Owner 的資料
//

import Foundation
import CloudKit

class FridgeZoneRepository {

    private let ckContainer: CKContainer

    init(containerIdentifier: String = "iCloud.FridgeHelper") {
        self.ckContainer = CKContainer(identifier: containerIdentifier)
    }

    /// 刪除失敗會丟出錯誤；zone 已經不存在視為成功
    func deleteZone(of fridge: Fridge) async throws {
        let database = fridge.isOwnedByCurrentUser ? ckContainer.privateCloudDatabase : ckContainer.sharedCloudDatabase
        let zoneID = fridge.zoneID
        let result = try await database.modifyRecordZones(saving: [], deleting: [zoneID])
        for (_, deletion) in result.deleteResults {
            do {
                try deletion.get()
            } catch let error as CKError where error.code == .zoneNotFound {
                continue
            }
        }
    }
}
