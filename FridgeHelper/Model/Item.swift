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
        self.memo = memo
        self.tag = tag
        self.image = image
        self.timeStamp = timeStamp
        self.zoneOwnerName = zoneOwnerName
        self.updatedByName = updatedByName
    }

    // MARK: - Zone 歸屬

    /// 是否存放在自己的 private zone；別人分享進來的食材不佔自己的額度
    var isInOwnZone: Bool {
        zoneOwnerName == nil || zoneOwnerName == CKCurrentUserDefaultName
    }
}
