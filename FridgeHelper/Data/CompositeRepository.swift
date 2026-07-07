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
//  - update 對同一 item 採 single-flight：同時最多一個上傳在飛，
//    飛行期間的變更以 dirty 標記合併，結束後補傳一次最新狀態，
//    保證最後落地的請求必定夾帶最終值（連點數量時雲端不會被舊值蓋掉）

import Foundation

/// Owner 裝置使用的 Repository。
/// fetch 只讀本地 SwiftData（快），寫入同時更新本地與 CloudKit（best-effort）。
@MainActor
class CompositeRepository: ItemRepositoryProtocol {

    private let local: ItemRepositoryProtocol
    private let cloud: ItemRepositoryProtocol

    // 每個 item 同時最多一個上傳在飛；飛行期間的更新以 dirty 標記合併
    private var uploadTasks: [String: Task<Void, Never>] = [:]
    private var dirtyKeys: Set<String> = []

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
        Task {
            do {
                try await cloud.add(item: item)
            } catch {
                printInfo("Save To Cloud Failed: \(error)")
            }
        }
    }

    func update(item: Item) async throws {
        try await local.update(item: item)
        pushUpdateToCloud(item)
    }

    func delete(item: Item) async throws {
        let key = item.timeStamp ?? ""
        try await local.delete(item: item)
        dirtyKeys.remove(key)       // 取消尚未補傳的更新，避免刪除後 record 在雲端被復活
        let pending = uploadTasks[key]
        Task {
            await pending?.value    // 等在飛的上傳結束，確保 delete 最後到達
            try? await cloud.delete(item: item)
        }
    }

    // MARK: - Single-flight upload

    private func pushUpdateToCloud(_ item: Item) {
        let key = item.timeStamp ?? ""
        guard uploadTasks[key] == nil else {
            dirtyKeys.insert(key)
            return
        }
        uploadTasks[key] = Task {
            repeat {
                dirtyKeys.remove(key)
                do {
                    try await cloud.update(item: item)  // toRecord 讀取的是 item 當下最新狀態
                } catch {
                    printInfo("Cloud Update Failed: \(error)")
                }
            } while dirtyKeys.contains(key)
            uploadTasks[key] = nil
        }
    }
}
