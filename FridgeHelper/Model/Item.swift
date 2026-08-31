//
//  item.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import Foundation
import UIKit
import SwiftData
import CloudKit

@Model
class Item {
    var name: String = ""
    var number: Int = 0
    var unit: String = "pcs"
    var expiryDate: Date = Date()
    /// Legacy 欄位：舊版慣例 0=冷凍、1=冷藏、2=室溫。保留供舊版 CloudKit 相容，新邏輯一律用 storeLocation
    var storeCondition: Int = 0
    var storeLocation: String = ""
    var memo: String?
    var tag: String?
    @Attribute(.externalStorage) var image: Data?
    var timeStamp: String?
    /// CloudKit zone 的擁有者 ID。nil 或等於 CKCurrentUserDefaultName 表示自己的 private zone；
    /// 其他值表示來自他人共享的 zone，寫回時需走 sharedCloudDatabase。
    var zoneOwnerName: String?
    /// 所屬冰箱（`Fridge.fridgeID`）。只存在本機、不寫進 CKRecord；
    /// 雲端的真相是 record 的 zoneID，同步時反推。空字串表示尚未經過 Fridge 遷移
    var fridgeID: String = ""
    var updatedByName: String?

    init(name: String, number: Int, unit: String = "pcs", expiryDate: Date, storeLocation: String, memo: String? = nil, tag: String? = nil, image: Data? = nil, timeStamp: String? = nil, zoneOwnerName: String? = nil, updatedByName: String? = nil) {
        self.name = name
        self.number = number
        self.unit = unit
        self.expiryDate = expiryDate
        self.storeLocation = storeLocation
        self.storeCondition = Item.legacyIndex(for: storeLocation)
        self.memo = memo
        self.tag = tag
        self.image = image
        self.timeStamp = timeStamp
        self.zoneOwnerName = zoneOwnerName
        self.updatedByName = updatedByName
    }

    // MARK: - Legacy 對照（0=冷凍、1=冷藏、2=室溫）

    static func location(fromLegacy index: Int) -> String {
        switch index {
        case 0: return "冷凍"
        case 2: return "室溫"
        default: return "冷藏"
        }
    }

    static func legacyIndex(for location: String) -> Int {
        switch location {
        case "冷凍": return 0
        case "室溫": return 2
        default: return 1
        }
    }

    // MARK: - Zone 歸屬

    /// 是否存放在自己的 private zone；別人分享進來的食材不佔自己的額度
    var isInOwnZone: Bool {
        zoneOwnerName == nil || zoneOwnerName == CKCurrentUserDefaultName
    }
}
