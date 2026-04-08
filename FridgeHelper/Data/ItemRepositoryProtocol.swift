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
    func add(item: Item) async throws
    func update(item: Item) async throws
    func delete(item: Item) async throws
}
