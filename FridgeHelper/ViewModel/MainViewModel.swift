//
//  MainViewModel.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/4/10.
//

import Foundation
import Combine

protocol NotificationManagerDelegate: AnyObject {
    func rescheduleNotification(for item: Item)
    func removeNotifications(for item: Item)
}

enum SortMethod: String, CaseIterable {
    case 取消
    case 時間排序遠到近 = "時間排序－遠到近"
    case 時間排序近到遠 = "時間排序－近到遠"
    case 剩餘數量多到少 = "剩餘數量－多到少"
    case 剩餘數量少到多 = "剩餘數量－少到多"

    func sortItems(_ items: [Item]) -> [Item] {
        switch self {
        case .取消: return items
        case .時間排序遠到近: return items.sorted { $0.expiryDate < $1.expiryDate }
        case .時間排序近到遠: return items.sorted { $0.expiryDate > $1.expiryDate }
        case .剩餘數量多到少: return items.sorted { $0.number > $1.number }
        case .剩餘數量少到多: return items.sorted { $0.number < $1.number }
        }
    }
}

enum TableUpdateEvent {
    case reload
    case deleteSection(Int)
    case reloadSection(Int)
}

class MainViewModel {
    // Inputs (ViewController writes)
    @Published var sortOption: SortMethod = .取消
    @Published var searchKeyword: String = ""
    @Published var segmentIndex: Int = 0

    // Outputs (ViewController subscribes)
    @Published private(set) var displayedItems: [Item] = []
    @Published private(set) var expiredItems: [Item] = []
    @Published private(set) var expiredCount: Int = 0

    let tableUpdateEvent = PassthroughSubject<TableUpdateEvent, Never>()

    // Private state
    private var savedItems: [Item] = []
    private var cancellables = Set<AnyCancellable>()
    weak var notificationDelegate: NotificationManagerDelegate?

    private let tagViewModel: TagViewModel

    init(tagViewModel: TagViewModel) {
        self.tagViewModel = tagViewModel
        loadItems()
        setupPipeline()
    }

    private func loadItems() {
        savedItems = FileMgr.shared.fetchItems() ?? []
        updateDerivedState()
    }

    private func setupPipeline() {
        let debouncedKeyword = $searchKeyword
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)

        // React to filter/sort/search changes (skip initial emission to avoid double-reload on setup)
        Publishers.CombineLatest4($sortOption, debouncedKeyword, $segmentIndex, tagViewModel.$selectedTag)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] sort, keyword, segment, tag in
                guard let self else { return }
                self.displayedItems = self.applyFilters(
                    items: self.savedItems,
                    sort: sort,
                    keyword: keyword,
                    segment: segment,
                    tag: tag
                )
                self.tableUpdateEvent.send(.reload)
            }
            .store(in: &cancellables)
    }

    private func updateDerivedState() {
        displayedItems = applyFilters(
            items: savedItems,
            sort: sortOption,
            keyword: searchKeyword,
            segment: segmentIndex,
            tag: tagViewModel.selectedTag
        )
        let expired = savedItems.filter { $0.expiryDate.timeIntervalSinceNow <= 259200 }
        expiredItems = expired
        expiredCount = expired.count
    }

    private func applyFilters(items: [Item], sort: SortMethod, keyword: String, segment: Int, tag: String?) -> [Item] {
        var result = sort.sortItems(items)
        if !keyword.isEmpty {
            result = result.filter { $0.name.contains(keyword) }
        }
        if let tag {
            result = result.filter { $0.tag == tag }
        }
        switch segment {
        case 1: result = result.filter { $0.storeCondition == 0 }
        case 2: result = result.filter { $0.storeCondition == 1 }
        case 3: result = result.filter { $0.storeCondition == 2 }
        default: break
        }
        return result
    }

    // MARK: - CRUD

    func addItem(_ item: Item) {
        savedItems.insert(item, at: 0)
        persist()
        notificationDelegate?.rescheduleNotification(for: item)
        updateDerivedState()
        tableUpdateEvent.send(.reload)
    }

    func removeItem(at displayedIndex: Int) {
        guard displayedIndex < displayedItems.count else { return }
        let item = displayedItems[displayedIndex]
        savedItems.removeAll { $0.timeStamp == item.timeStamp }
        persist()
        notificationDelegate?.removeNotifications(for: item)
        updateDerivedState()
        tableUpdateEvent.send(.deleteSection(displayedIndex))
    }

    func updateItem(at displayedIndex: Int, with newItem: Item) {
        guard displayedIndex < displayedItems.count else { return }
        let oldItem = displayedItems[displayedIndex]
        guard let savedIndex = savedItems.firstIndex(where: { $0.timeStamp == oldItem.timeStamp }) else { return }
        savedItems[savedIndex] = newItem
        persist()
        notificationDelegate?.removeNotifications(for: oldItem)
        notificationDelegate?.rescheduleNotification(for: newItem)
        updateDerivedState()
        // Use reloadSection only if item remains at same index after filtering
        if displayedIndex < displayedItems.count,
           displayedItems[displayedIndex].timeStamp == newItem.timeStamp {
            tableUpdateEvent.send(.reloadSection(displayedIndex))
        } else {
            tableUpdateEvent.send(.reload)
        }
    }

    func refreshExpiredItems() {
        let expired = savedItems.filter { $0.expiryDate.timeIntervalSinceNow <= 259200 }
        expiredItems = expired
        expiredCount = expired.count
    }

    private func persist() {
        if savedItems.isEmpty {
            FileMgr.shared.removeItems()
        } else {
            FileMgr.shared.saveItems(savedItems)
        }
    }
}
