//
//  FridgeViewModel.swift
//  FridgeHelper
//
//  Created by 姐夫 on 2026/9/26.
//

import Foundation
import Combine

class FridgeViewModel {
    @Published private(set) var fridges: [Fridge] = []

    init(fridges: [Fridge] = []) {
        self.fridges = fridges
    }
}

// MARK: - Mock

#if DEBUG
extension FridgeViewModel {
    /// 測試用：不碰 SwiftData，直接塞假冰箱給冰箱選擇頁
    static func mock() -> FridgeViewModel {
        FridgeViewModel(fridges: Fridge.mockList)
    }
}

extension Fridge {
    /// 未 insert 進 ModelContext 的假資料，只供畫面測試
    static var mockList: [Fridge] {
        [
            Fridge(zoneName: "Default", ownerName: nil, name: "我的冰箱",
                   plan: .familyLifetime,
                   tags: FridgeListDefaults.tags, locations: FridgeListDefaults.locations),
            Fridge(zoneName: "Office", ownerName: nil, name: "公司冰箱",
                   plan: .familyLifetime,
                   tags: ["飲料", "點心"], locations: ["冷藏", "冷凍"]),
            Fridge(zoneName: "Garage", ownerName: nil, name: "車庫冷凍櫃",
                   plan: .familyLifetime,
                   tags: ["肉類", "魚類"], locations: ["冷凍"]),
            Fridge(zoneName: "Shared-1", ownerName: "_mockOwnerA", name: FridgeDefaultName.shared(from: "媽媽"),
                   tags: FridgeListDefaults.tags, locations: FridgeListDefaults.locations),
            Fridge(zoneName: "Shared-2", ownerName: "_mockOwnerB", name: FridgeDefaultName.sharedFallback,
                   tags: [], locations: FridgeListDefaults.locations),
        ]
    }
}
#endif
