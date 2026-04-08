//
//  TagViewModel.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/5/17.
//

import Foundation
import Combine

enum TagTableUpdateEvent {
    case reload
    case deleteRow(Int)
}

class TagViewModel {
    @Published private(set) var tags: [String] = []
    @Published var selectedTag: String? = nil

    let tableUpdateEvent = PassthroughSubject<TagTableUpdateEvent, Never>()

    private let repository: TagRepositoryProtocol

    init(repository: TagRepositoryProtocol) {
        self.repository = repository
        loadTags()
    }

    func loadTags() {
        let defaultTags = ["蔬菜", "水果", "肉類", "魚類"]
        let fetched = repository.fetchTags()
        tags = fetched.isEmpty ? defaultTags : fetched
    }

    func addTag(_ name: String) {
        guard !name.isEmpty else { return }
        tags.append(name)
        repository.saveTags(tags)
        tableUpdateEvent.send(.reload)
    }

    func removeTag(at index: Int) {
        guard index < tags.count else { return }
        let removed = tags[index]
        tags.remove(at: index)
        repository.saveTags(tags)
        // If the removed tag was selected, clear selection
        if selectedTag == removed {
            selectedTag = nil
        }
        if tags.isEmpty {
            tableUpdateEvent.send(.reload)
        } else {
            tableUpdateEvent.send(.deleteRow(index))
        }
    }
}
