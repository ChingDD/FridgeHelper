//
//  CompositeRepository.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/11.
//
//  職責：Owner 裝置的 write-through Repository
//
//  Write-through 快取策略：
//  - 寫入時同時更新快取（local SwiftData）與後端（CloudKit）
//  - 與 write-back 的差異：每次操作立刻觸發後端寫入，而非延遲批次同步
//
//  - fetch() 只讀本地 SwiftData（速度快）
//  - add / update / delete 先寫本地，再背景非同步寫 CloudKit（best-effort，失敗不阻塞 UI）

import Foundation

/// Owner 裝置使用的 Repository。
/// fetch 只讀本地 SwiftData（快），寫入同時更新本地與 CloudKit（best-effort）。
@MainActor
class CompositeRepository: ItemRepositoryProtocol {

    private let local: ItemRepositoryProtocol
    private let cloud: ItemRepositoryProtocol
    private var cloudWriteTasks: [String: Task<Void, Never>] = [:]

    init(local: ItemRepositoryProtocol, cloud: ItemRepositoryProtocol) {
        self.local = local
        self.cloud = cloud
    }

    // MARK: - ItemRepositoryProtocol

    func fetch() async throws -> [Item] {
        try await local.fetch()
    }

    func add(item: Item) async throws {
        try await local.add(item: item)
        enqueueCloudWrite(for: item) { [cloud] item in
            try await cloud.add(item: item)
        }
    }

    func update(item: Item) async throws {
        try await local.update(item: item)
        enqueueCloudWrite(for: item) { [cloud] item in
            try await cloud.update(item: item)
        }
    }

    func delete(item: Item) async throws {
        try await local.delete(item: item)
        enqueueCloudWrite(for: item) { [cloud] item in
            try await cloud.delete(item: item)
        }
    }

    private func enqueueCloudWrite(for item: Item, operation: @escaping (Item) async throws -> Void) {
        let snapshot = item.cloudSnapshot()
        let key = snapshot.timeStamp ?? UUID().uuidString
        let previousTask = cloudWriteTasks[key]

        cloudWriteTasks[key] = Task { @MainActor in
            await previousTask?.value
            do {
                try await operation(snapshot)
            } catch {
                printInfo("Save To Cloud Failed: \(error)")
            }
        }
    }
}

private extension Item {
    func cloudSnapshot() -> Item {
        Item(
            name: name,
            number: number,
            expiryDate: expiryDate,
            storeCondition: storeCondition,
            memo: memo,
            tag: tag,
            image: image,
            timeStamp: timeStamp,
            zoneOwnerName: zoneOwnerName,
            updatedByName: updatedByName
        )
    }
}
