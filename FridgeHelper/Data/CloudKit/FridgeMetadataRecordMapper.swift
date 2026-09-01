//
//  FridgeMetadataRecordMapper.swift
//  FridgeHelper
//
//  Fridge ↔ FridgeMetadata CKRecord 的唯一映射點
//
//  每個 Zone 固定一筆 FridgeMetadata，讓「冰箱本身」成為可同步的資料：
//  - 沒有任何食材的冰箱在雲端本來一筆 record 都沒有，成員同步時看不到它存在
//  - 成員無法驗證 Owner 的 StoreKit 購買，只能從這裡讀到 Owner 的方案
//

import Foundation
import CloudKit

enum FridgeMetadataRecordMapper {
    static let recordType = "FridgeMetadata"
    /// 每個 zone 固定一筆，recordName 寫死才能 upsert
    static let recordName = "fridgeMetadata"

    static func recordID(in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: recordName, zoneID: zoneID)
    }

    static func populate(_ record: CKRecord, from fridge: Fridge) {
        // Owner 裝置視角的 fridgeID，僅供診斷。
        // 讀取端一律以 record 所在的 zoneID 為準：同一座 zone 在成員裝置上的 ownerName 不同
        record["fridgeID"] = fridge.fridgeID as CKRecordValue
        record["plan"] = fridge.plan.rawValue as CKRecordValue
        record["createdAt"] = fridge.createdAt as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
    }

    /// 內容與本機一致就不需要再寫一次。
    /// 每次啟動都無條件 save 會讓其他裝置收到一次沒有意義的 silent push
    static func isUpToDate(_ record: CKRecord, for fridge: Fridge) -> Bool {
        record["plan"] as? String == fridge.plan.rawValue
    }

    struct Snapshot {
        let plan: FridgePlan
        let createdAt: Date
    }

    static func snapshot(from record: CKRecord) -> Snapshot {
        Snapshot(
            plan: (record["plan"] as? String).flatMap(FridgePlan.init(rawValue:)) ?? .free,
            createdAt: record["createdAt"] as? Date ?? Date()
        )
    }
}
