//
//  ItemRepositoryProtocol.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/8.
//

import Foundation

@MainActor
protocol ItemRepositoryProtocol {
    func fetch() async throws -> [Item]
    /// 只取單一冰箱的食材
    func fetch(fridgeID: String) async throws -> [Item]
    /// 單一冰箱的食材數；容量檢查用，不需要把整份清單載進記憶體
    func count(fridgeID: String) async throws -> Int
    func add(item: Item) async throws
    func update(item: Item) async throws
    func delete(item: Item) async throws
}
