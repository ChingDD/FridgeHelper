//
//  FridgePlan.swift
//  FridgeHelper
//
//  方案限制集中定義：冰箱數、食材上限、可邀請成員數只在這裡出現，不散落到 ViewController
//

import Foundation

/// 冰箱方案。權益跟著冰箱 Owner，成員沿用該冰箱 Owner 的方案
enum FridgePlan {
    case free
    case familyLifetime

    /// 可擁有的冰箱數
    var ownedFridges: Int {
        switch self {
        case .free: return 1
        case .familyLifetime: return 3
        }
    }

    /// 每座冰箱的食材上限
    var itemsPerFridge: Int {
        switch self {
        case .free: return 100
        case .familyLifetime: return 500
        }
    }

    /// 每座冰箱可邀請的成員數；不含 Owner，含尚未接受的邀請
    var invitedMembersPerFridge: Int {
        switch self {
        case .free: return 1
        case .familyLifetime: return 4
        }
    }
}

/// 方案來源。階段四接上 StoreKit 後改由購買權益決定，呼叫端不需要調整
protocol FridgePlanProviding {
    /// 取得該冰箱 Zone Owner 的方案；自己的冰箱傳 CKCurrentUserDefaultName
    func plan(forZoneOwner ownerName: String) -> FridgePlan
}

/// 階段四 StoreKit 完成前的暫時實作：所有冰箱一律免費方案
struct FreeFridgePlanProvider: FridgePlanProviding {
    func plan(forZoneOwner ownerName: String) -> FridgePlan { .free }
}

/// 新增食材被容量擋下的原因；更新與刪除永遠不經過容量檢查
enum ItemCapacityRejection {
    /// 自己是這座冰箱的 Owner，可升級家庭版提高上限
    case ownerCanUpgrade(capacity: Int)
    /// 已經是方案的最大額度，只能先刪除食材
    case planMaxReached(capacity: Int)

    var alertTitle: String { "已達食材上限" }

    var alertMessage: String {
        switch self {
        case .ownerCanUpgrade(let capacity):
            return "此冰箱已達 \(capacity) 項上限，升級家庭版可提高上限。"
        case .planMaxReached(let capacity):
            return "此冰箱已達 \(capacity) 項上限，請先刪除不需要的食材。"
        }
    }
}
