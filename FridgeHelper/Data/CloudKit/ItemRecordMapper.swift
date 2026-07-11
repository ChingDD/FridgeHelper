//
//  ItemRecordMapper.swift
//  FridgeHelper
//
//  Item ↔ CKRecord 的唯一映射點（CloudRepository 與 SyncCoordinator 共用）
//

import CloudKit
import UIKit

enum ItemRecordMapper {

    /// 將 item 欄位寫入 record。若有圖片會寫入暫存檔，回傳其 URL，caller 負責上傳後刪除。
    static func populate(_ record: CKRecord, from item: Item) -> URL? {
        record["name"] = item.name
        record["quantity"] = item.number as CKRecordValue
        record["unit"] = item.unit as CKRecordValue
        record["expiry"] = item.expiryDate as CKRecordValue
        // legacy Int 欄位照寫，讓尚未更新的裝置能繼續運作
        record["store"] = Item.legacyIndex(for: item.storeLocation) as CKRecordValue
        record["storeLocation"] = item.storeLocation as CKRecordValue
        record["memo"] = item.memo as CKRecordValue?
        record["tag"] = item.tag as CKRecordValue?
        record["timestamp"] = item.timeStamp as CKRecordValue?
        record["updatedByName"] = UIDevice.current.name as CKRecordValue

        var tempURL: URL? = nil
        if let imageData = item.image {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? imageData.write(to: url)
            record["image"] = CKAsset(fileURL: url)
            tempURL = url
        }
        return tempURL
    }

    static func item(from record: CKRecord) -> Item {
        // 優先讀新欄位，舊版寫的記錄 fallback 到 legacy store Int
        let storeLocation = (record["storeLocation"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? Item.location(fromLegacy: (record["store"] as? Int64).map { Int($0) } ?? 1)

        var imageData: Data? = nil
        if let asset = record["image"] as? CKAsset, let url = asset.fileURL {
            imageData = try? Data(contentsOf: url)
        }

        return Item(
            name: record["name"] as? String ?? "",
            number: (record["quantity"] as? Int64).map { Int($0) } ?? 0,
            unit: record["unit"] as? String ?? "pcs",
            expiryDate: record["expiry"] as? Date ?? Date(),
            storeLocation: storeLocation,
            memo: record["memo"] as? String,
            tag: record["tag"] as? String,
            image: imageData,
            timeStamp: record["timestamp"] as? String,
            zoneOwnerName: record.recordID.zoneID.ownerName,
            updatedByName: record["updatedByName"] as? String
        )
    }
}
