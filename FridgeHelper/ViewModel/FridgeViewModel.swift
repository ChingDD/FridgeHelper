//
//  FridgeViewModel.swift
//  FridgeHelper
//
//  冰箱選擇首頁的資料來源：本機 SwiftData 的 Fridge 清單
//

import Foundation
import Combine
import CloudKit
import SwiftData

@MainActor
class FridgeViewModel {
    @Published private(set) var fridges: [Fridge] = []

    private let context: ModelContext?
    private let planProvider: FridgePlanProviding
    private let metadataRepository: FridgeMetadataRepository?
    private let zoneRepository: FridgeZoneRepository?
    private let localRemover: FridgeLocalRemover?
    private var cancellables = Set<AnyCancellable>()

    /// 正式用：從 SwiftData 讀取，雲端同步完成後（可能新增共享冰箱）自動重讀
    init(
        context: ModelContext,
        planProvider: FridgePlanProviding,
        metadataRepository: FridgeMetadataRepository,
        zoneRepository: FridgeZoneRepository,
        localRemover: FridgeLocalRemover
    ) {
        self.context = context
        self.planProvider = planProvider
        self.metadataRepository = metadataRepository
        self.zoneRepository = zoneRepository
        self.localRemover = localRemover
        loadFridges()
        NotificationCenter.default.publisher(for: .cloudKitDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.loadFridges() }
            .store(in: &cancellables)
    }

    /// 預覽／測試用：直接給定清單
    init(fridges: [Fridge] = []) {
        self.context = nil
        self.planProvider = FreeFridgePlanProvider()
        self.metadataRepository = nil
        self.zoneRepository = nil
        self.localRemover = nil
        self.fridges = fridges
    }

    func loadFridges() {
        guard let context else { return }
        // 自己的冰箱排前面，共享進來的排後面，各組內依建立時間
        let all = (try? context.fetch(FetchDescriptor<Fridge>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        fridges = all.filter(\.isOwnedByCurrentUser) + all.filter { !$0.isOwnedByCurrentUser }
    }

    // MARK: - 建立／重新命名／刪除

    /// Default 冰箱每次啟動都會由 FridgeMigrator 補建，所以不開放刪除，只能改名
    static func isDefaultFridge(_ fridge: Fridge) -> Bool {
        fridge.isOwnedByCurrentUser && fridge.zoneName == ZoneManager.defaultZoneName
    }

    /// 目前是否還能建立冰箱；nil 代表可以。只計自己擁有的冰箱，共享進來的不占名額。
    /// 與 `addItemRejection` 一樣必須是同步的，連續點擊才不會同時通過而超出上限
    var createFridgeRejection: FridgeCreationRejection? {
        let plan = planProvider.plan(forZoneOwner: CKCurrentUserDefaultName)
        let limit = plan.ownedFridges
        guard fridges.filter(\.isOwnedByCurrentUser).count >= limit else { return nil }
        switch plan {
        case .free: return .ownerCanUpgrade(limit: limit)
        case .familyLifetime: return .planMaxReached(limit: limit)
        }
    }

    /// 建立自己的冰箱。先寫本機讓畫面立刻出現，再背景寫進雲端（zone 與 FridgeMetadata）；
    /// 雲端失敗只記錄，下次啟動 `pushOwnedFridgeMetadata` 會對所有冰箱補傳。
    /// 回傳被上限擋下的原因，nil 代表已受理（名稱為空白時不建立）
    func createFridge(name: String) -> FridgeCreationRejection? {
        if let rejection = createFridgeRejection { return rejection }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let context, !trimmed.isEmpty else { return nil }

        let fridge = Fridge(
            zoneName: "Fridge_\(UUID().uuidString)",
            ownerName: nil,
            name: trimmed,
            plan: planProvider.plan(forZoneOwner: CKCurrentUserDefaultName),
            tags: FridgeListDefaults.tags,
            locations: FridgeListDefaults.locations
        )
        context.insert(fridge)
        do {
            try context.save()
        } catch {
            printInfo("Create Fridge Error: \(error)")
            context.delete(fridge)
            return nil
        }
        loadFridges()

        Task { @MainActor [weak self] in
            do {
                try await self?.metadataRepository?.upsert(for: fridge)
            } catch {
                printInfo("FridgeMetadata 上傳失敗: \(error)")
            }
        }
        return nil
    }

    /// 重新命名。名稱純本機、不同步，共享冰箱各成員也可以各自改名
    func renameFridge(_ fridge: Fridge, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let context, !trimmed.isEmpty, trimmed != fridge.name else { return }
        fridge.name = trimmed
        do {
            try context.save()
        } catch {
            printInfo("Rename Fridge Error: \(error)")
        }
        loadFridges()
    }

    /// 刪除自己的冰箱，或離開別人共享的冰箱。
    /// 先處理雲端、成功後才清本機：雲端失敗時保留本機資料，
    /// 否則 zone 還在，下次同步又會把冰箱重建回來。Default 冰箱不可刪除
    func deleteFridge(_ fridge: Fridge) async throws {
        guard !Self.isDefaultFridge(fridge),
              let zoneRepository, let localRemover else { return }
        // 雲端操作期間同步可能已移除這座冰箱，先把需要的值取出來
        let fridgeID = fridge.fridgeID
        try await zoneRepository.deleteZone(of: fridge)
        try localRemover.remove(fridgeID: fridgeID)
        loadFridges()
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
