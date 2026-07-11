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

class MainViewModel {
    // Inputs (ViewController writes)
    @Published var sortOption: SortMethod = .取消
    @Published var searchKeyword: String = ""

    // Outputs (ViewController subscribes)
    @Published private(set) var displayedItems: [Item] = []
    @Published private(set) var expiredItems: [Item] = []
    @Published private(set) var expiredCount: Int = 0

    // User-defined lists（篩選選取狀態也在這兩個 VM 上）
    let tags: StringListViewModel
    let locations: StringListViewModel

    // Repository
    let localRepository: ItemRepositoryProtocol

    // Private state
    private var savedItems: [Item] = []
    private var cancellables = Set<AnyCancellable>()
    private var initialNotificationsScheduled = false
    private var isSyncingFromCloud = false                  // 避免同時間重複 sync
    private let syncFromCloud: (() async throws -> Void)?   // 同步 Cloud 的入口由外部注入

    weak var notificationDelegate: NotificationManagerDelegate? {
        didSet {
            guard notificationDelegate != nil, !initialNotificationsScheduled else { return }
            initialNotificationsScheduled = true
            for item in savedItems {
                notificationDelegate?.rescheduleNotification(for: item)
            }
        }
    }

    init(tags: StringListViewModel, locations: StringListViewModel, local: ItemRepositoryProtocol, syncFromCloud: (() async throws -> Void)? = nil) {
        self.tags = tags
        self.locations = locations
        self.localRepository = local
        self.syncFromCloud = syncFromCloud
        loadItems()
        setupPipeline()
    }

    private func loadItems() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let items = (try? await self.localRepository.fetch()) ?? []
            self.savedItems = items
            self.updateDerivedState()

            // Schedule initial notifications if delegate is already set
            if !self.initialNotificationsScheduled, self.notificationDelegate != nil {
                self.initialNotificationsScheduled = true
                for item in self.savedItems {
                    self.notificationDelegate?.rescheduleNotification(for: item)
                }
            }
        }
    }

    private func setupPipeline() {
        let debouncedKeyword = $searchKeyword
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)

        // React to filter/sort/search changes (skip initial emission to avoid double-reload on setup)
        Publishers.CombineLatest4($sortOption, debouncedKeyword, locations.$selected, tags.$selected)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] sort, keyword, location, tag in
                guard let self else { return }
                self.displayedItems = self.applyFilters(
                    items: self.savedItems,
                    sort: sort,
                    keyword: keyword,
                    location: location,
                    tag: tag
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudKitDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.loadItems() }
            .store(in: &cancellables)
    }

    func syncFromCloudIfNeeded() {
        guard let syncFromCloud else { return }
        guard !isSyncingFromCloud else { return }

        isSyncingFromCloud = true
        Task { @MainActor [weak self] in
            defer { self?.isSyncingFromCloud = false }
            do {
                try await syncFromCloud()
            } catch {
                printInfo("Sync Cloud To Local Fail: \(error)")
            }
        }
    }

    private func updateDerivedState() {
        displayedItems = applyFilters(
            items: savedItems,
            sort: sortOption,
            keyword: searchKeyword,
            location: locations.selected,
            tag: tags.selected
        )
        let expired = savedItems.filter { $0.expiryDate.timeIntervalSinceNow <= 259200 }
        expiredItems = expired
        expiredCount = expired.count
    }

    private func applyFilters(items: [Item], sort: SortMethod, keyword: String, location: String?, tag: String?) -> [Item] {
        var result = sort.sortItems(items)
        if !keyword.isEmpty {
            result = result.filter { $0.name.contains(keyword) }
        }
        if let tag {
            result = result.filter { $0.tag == tag }
        }
        if let location {
            result = result.filter { $0.storeLocation == location }
        }
        return result
    }

    // MARK: - CRUD

    func addItem(_ item: Item) {
        savedItems.insert(item, at: 0)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.localRepository.add(item: item)
                self.notificationDelegate?.rescheduleNotification(for: item)
                self.updateDerivedState()
            } catch {
                printInfo("Add Item Error: \(error)")
            }
        }
    }

    func removeItem(_ item: Item) {
        savedItems.removeAll { $0.timeStamp == item.timeStamp }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.localRepository.delete(item: item)
                self.notificationDelegate?.removeNotifications(for: item)
                self.updateDerivedState()
            } catch {
                printInfo("Remove Item Error: \(error)")
            }
        }
    }

    func updateItem(_ item: Item, with newItem: Item) {
        guard savedItems.contains(where: { $0.timeStamp == item.timeStamp }) else { return }

        // Update managed object properties in-place (SwiftData tracks changes via @Model)
        item.name = newItem.name
        item.number = newItem.number
        item.unit = newItem.unit
        item.expiryDate = newItem.expiryDate
        item.storeCondition = newItem.storeCondition
        item.storeLocation = newItem.storeLocation
        item.memo = newItem.memo
        item.tag = newItem.tag
        item.image = newItem.image

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.localRepository.update(item: item)
                self.notificationDelegate?.removeNotifications(for: item)
                self.notificationDelegate?.rescheduleNotification(for: item)
                self.updateDerivedState()
            } catch {
                printInfo("Update Item Error: \(error)")
            }
        }
    }

    /// 卡片上 stepper 直接調整數量（CompositeRepository 的 single-flight 會合併頻繁上傳）
    func updateQuantity(of item: Item, to value: Int) {
        item.number = value
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.localRepository.update(item: item)
                self.updateDerivedState()
            } catch {
                printInfo("Update Quantity Error: \(error)")
            }
        }
    }

    func refreshExpiredItems() {
        let expired = savedItems.filter { $0.expiryDate.timeIntervalSinceNow <= 259200 }
        expiredItems = expired
        expiredCount = expired.count
    }
}
