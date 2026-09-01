//
//  Fridge.swift
//  FridgeHelper
//
//  一座冰箱＝一個 CloudKit Record Zone。純本機資料，不同步到雲端：
//  雲端的真相是 zoneID，重裝後由 SyncCoordinator 從 record 的 zoneID 反推重建
//

import Foundation
import SwiftData
import CloudKit

@Model
class Fridge {
    /// 字串化的 zoneID，格式 `"<ownerName>|<zoneName>"`；對應 `Item.fridgeID`
    var fridgeID: String = ""
    /// 顯示名稱。純本機，不同步給其他成員
    var name: String = ""
    /// CloudKit Zone 名稱
    var zoneName: String = ""
    /// CloudKit Zone Owner；自己的 zone 一律正規化為 CKCurrentUserDefaultName
    var ownerName: String = ""
    var plan: FridgePlan = FridgePlan.free
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// 這座冰箱的標籤清單
    var tags: [String] = []
    /// 這座冰箱的儲存位置清單
    var locations: [String] = []

    init(zoneName: String, ownerName: String?, name: String, plan: FridgePlan = .free, tags: [String], locations: [String]) {
        let owner = Fridge.normalizedOwnerName(ownerName)
        self.fridgeID = Fridge.makeID(zoneName: zoneName, ownerName: owner)
        self.name = name
        self.zoneName = zoneName
        self.ownerName = owner
        self.plan = plan
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
        self.locations = locations
    }

    // MARK: - ID 組成

    /// 自己的 zone 一律用 CKCurrentUserDefaultName 表示。
    /// 同一座冰箱在 Owner 裝置上是 `__defaultOwner__`、在 CKShare 上是真實 user record name，
    /// 不正規化會在本機產生兩筆 Fridge
    static func normalizedOwnerName(_ ownerName: String?) -> String {
        guard let ownerName, !ownerName.isEmpty, ownerName != CKCurrentUserDefaultName else {
            return CKCurrentUserDefaultName
        }
        return ownerName
    }

    static func makeID(zoneName: String, ownerName: String?) -> String {
        "\(normalizedOwnerName(ownerName))|\(zoneName)"
    }

    /// 從字串化的 fridgeID 還原 zoneID。
    /// 有了這條反向路徑，雲端寫入不需要先查 Fridge，拿 Item 的 fridgeID 就能決定要寫哪個 zone
    static func zoneID(from fridgeID: String) -> CKRecordZone.ID? {
        let parts = fridgeID.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return CKRecordZone.ID(zoneName: String(parts[1]), ownerName: String(parts[0]))
    }

    /// zone 是否屬於自己。自己的 zone 才能建立，也才走 privateDB
    static func isOwnZone(_ zoneID: CKRecordZone.ID) -> Bool {
        normalizedOwnerName(zoneID.ownerName) == CKCurrentUserDefaultName
    }

    /// 這座冰箱對應的 CloudKit Zone
    var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
    }

    /// 是否為自己擁有的冰箱；別人分享進來的冰箱不佔自己的額度
    var isOwnedByCurrentUser: Bool {
        ownerName == CKCurrentUserDefaultName
    }
}

/// 記住上次選取的冰箱。階段三接上冰箱選擇首頁後改由該頁寫入
enum SelectedFridgeStore {
    private static let key = "app.fridge.selectedID"

    static var fridgeID: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// 冰箱的預設顯示名稱。名稱純本機、不同步，各裝置可以各自改名
enum FridgeDefaultName {
    static let own = "我的冰箱"
    /// 取不到分享者身分時的共享冰箱名稱
    static let sharedFallback = "共享的冰箱"

    /// 共享冰箱以分享者命名
    static func shared(from ownerName: String?) -> String {
        guard let ownerName, !ownerName.isEmpty else { return sharedFallback }
        return "\(ownerName) 的冰箱"
    }
}

/// 標籤／儲存位置的系統預設值，以及 2A 之前清單存放的 UserDefaults key（遷移來源）
enum FridgeListDefaults {
    static let tags = ["蔬菜", "水果", "肉類", "魚類"]
    static let locations = ["室溫", "冷藏", "冷凍"]

    static let legacyTagsKey = "app.swiftdata.tags"
    static let legacyLocationsKey = "app.swiftdata.storeLocations"
}
