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

    init() {
        loadTags()
    }

    func loadTags() {
        let defaultTags = ["蔬菜", "水果", "肉類", "魚類"]
        if let fetched = FileMgr.shared.fetchTags() {
            tags = fetched
        } else {
            tags = defaultTags
        }
    }

    func addTag(_ name: String) {
        guard !name.isEmpty else { return }
        tags.append(name)
        FileMgr.shared.saveTags(tags: tags)
        tableUpdateEvent.send(.reload)
    }

    func removeTag(at index: Int) {
        guard index < tags.count else { return }
        let removed = tags[index]
        tags.remove(at: index)
        FileMgr.shared.saveTags(tags: tags)
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
