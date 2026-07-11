//
//  StringListViewModel.swift
//  FridgeHelper
//
//  使用者自訂字串清單（標籤、儲存位置）：UserDefaults 持久化＋選取狀態
//

import Foundation
import Combine

struct UserDefaultsStringListStore {
    let key: String

    func fetch() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func save(_ values: [String]) {
        UserDefaults.standard.set(values, forKey: key)
    }
}

class StringListViewModel {
    @Published private(set) var values: [String]
    @Published var selected: String?

    private let store: UserDefaultsStringListStore

    init(store: UserDefaultsStringListStore, defaults: [String]) {
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
