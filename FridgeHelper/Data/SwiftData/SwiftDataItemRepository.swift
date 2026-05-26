//
//  SwiftDataItemRepository.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/8.
//

import Foundation
import SwiftData

@MainActor
class SwiftDataItemRepository: ItemRepositoryProtocol, TagRepositoryProtocol {

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let tagsKey = "app.swiftdata.tags"

    init(container: ModelContainer) {
        self.container = container
    }

    func fetch() async throws -> [Item] {
        let descriptor = FetchDescriptor<Item>(
            sortBy: [SortDescriptor(\Item.timeStamp, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func add(item: Item) async throws {
        context.insert(item)
        try context.save()
    }

    func update(item: Item) async throws {
        try context.save()
    }

    func delete(item: Item) async throws {
        context.delete(item)
        try context.save()
    }

    // MARK: - Tags (UserDefaults)

    func fetchTags() -> [String] {
        return UserDefaults.standard.stringArray(forKey: tagsKey) ?? []
    }

    func saveTags(_ tags: [String]) {
        UserDefaults.standard.set(tags, forKey: tagsKey)
    }
}
