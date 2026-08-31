//
//  StringListViewModel.swift
//  FridgeHelper
//
//  使用者自訂字串清單（標籤、儲存位置）：持久化＋選取狀態
//

import Foundation
import Combine
import SwiftData

protocol StringListStore {
    func fetch() -> [String]
    func save(_ values: [String])
}

/// 多冰箱之前的清單來源，保留供 `FridgeMigrator` 的遷移路徑對照
struct UserDefaultsStringListStore: StringListStore {
    let key: String

    func fetch() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func save(_ values: [String]) {
        UserDefaults.standard.set(values, forKey: key)
    }
}

/// 讀寫某座冰箱上的清單欄位。清單跟著冰箱生命週期走，刪除冰箱時一併清除
struct FridgeStringListStore: StringListStore {
    let fridge: Fridge
    let keyPath: ReferenceWritableKeyPath<Fridge, [String]>
    let context: ModelContext

    func fetch() -> [String] {
        fridge[keyPath: keyPath]
    }

    func save(_ values: [String]) {
        fridge[keyPath: keyPath] = values
        fridge.updatedAt = Date()
        try? context.save()
    }
}

class StringListViewModel {
    @Published private(set) var values: [String]
    @Published var selected: String?

    private let store: StringListStore

    init(store: StringListStore, defaults: [String]) {
        self.store = store
        let saved = store.fetch()
        self.values = saved.isEmpty ? defaults : saved
        if saved.isEmpty {
            store.save(defaults)
        }
    }

    func add(_ value: String) {
        guard !value.isEmpty, !values.contains(value) else { return }
        values.append(value)
        store.save(values)
    }

    func remove(at index: Int) {
        guard values.indices.contains(index) else { return }
        let removed = values.remove(at: index)
        store.save(values)
        if selected == removed {
            selected = nil
        }
    }
}
