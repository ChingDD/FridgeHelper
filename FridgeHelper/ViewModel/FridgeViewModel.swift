//
//  FridgeViewModel.swift
//  FridgeHelper
//
//  冰箱選擇首頁的資料來源：本機 SwiftData 的 Fridge 清單
//

import Foundation
import Combine
import SwiftData

@MainActor
class FridgeViewModel {
    @Published private(set) var fridges: [Fridge] = []

    private let context: ModelContext?
    private var cancellables = Set<AnyCancellable>()

    /// 正式用：從 SwiftData 讀取，雲端同步完成後（可能新增共享冰箱）自動重讀
    init(context: ModelContext) {
        self.context = context
        loadFridges()
        NotificationCenter.default.publisher(for: .cloudKitDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.loadFridges() }
            .store(in: &cancellables)
    }

    /// 預覽／測試用：直接給定清單
    init(fridges: [Fridge] = []) {
        self.context = nil
        self.fridges = fridges
    }

    func loadFridges() {
        guard let context else { return }
        // 自己的冰箱排前面，共享進來的排後面，各組內依建立時間
        let all = (try? context.fetch(FetchDescriptor<Fridge>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        fridges = all.filter(\.isOwnedByCurrentUser) + all.filter { !$0.isOwnedByCurrentUser }
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
