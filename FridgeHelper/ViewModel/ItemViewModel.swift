//
//  LunchingViewModel.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/4/10.
//

import Foundation

protocol NotificationManagerDelegate: AnyObject {
    func rescheduleNotification(for item: Item)
    func removeNotifications(for item: Item)
}

enum ItemModifyStatus {
    case addItem
    case deletItem(index: Int)
    case modifiyItem(index: Int)
    case filter
    case none
}

class ItemViewModel {
    var savedItemsObservor: ObservableObject = ObservableObject<[Item]?>(value: nil)
    var expiredItemObservor: ObservableObject = ObservableObject<[Item]?>(value: nil)
    var showedItemsObservor: ObservableObject = ObservableObject<[Item]?>(value: nil)
    
    var itemModifyStatus: ItemModifyStatus = .none
    weak var notificationDelegate: NotificationManagerDelegate?
    
    init() {
        //讀取存在Document資料夾的items
        fetchSavedItems()
        fetchExpiredItems()
        showedItemsObservor.value = savedItemsObservor.value
    }
    
    func fetchSavedItems() {
        let items = FileMgr.shared.fetchItems()
        savedItemsObservor.value = items
    }
    
    func fetchExpiredItems() {
        //抓出有過期的物品
        let items = FileMgr.shared.fetchExpiredItems(savedItemsObservor.value)
        expiredItemObservor.value = items
    }
    
    private func searchKeywords(_ inputText: String?, items: [Item]?)->[Item]? {
        guard let items else { return nil }
        guard let inputText, !inputText.isEmpty else { return items }
        
        let result = items.filter({ $0.name.contains(inputText) })
        
        if result.isEmpty {
            return nil  //沒篩到東西
        } else {
            return result   //有篩到東西
        }
    }
    
    private func selectedTagItems(currentTag: String? = nil, items: [Item]?) -> [Item]? {
        guard let items else { return nil }
        guard let currentTag else { return items }
        
        let selectedTagItems = items.filter({ $0.tag == currentTag})
        if selectedTagItems.isEmpty {
            return nil
        } else {
            return selectedTagItems
        }
    }
    
    func updateShowedItems(segmentControllerIndex: Int,  sortOption: SortMethod, tag: String?, keyword: String?){
        var showedItems = savedItemsObservor.value
        showedItems = sortOption.sortShowedItems(showedItems)
        showedItems = searchKeywords(keyword, items: showedItems)
        showedItems = selectedTagItems(currentTag: tag, items: showedItems)
        switch segmentControllerIndex {
        case 0:
            break
        case 1:
            showedItems = showedItems?.filter { $0.storeCondition==0 }
        case 2:
            showedItems = showedItems?.filter { $0.storeCondition==1 }
        case 3:
            showedItems = showedItems?.filter { $0.storeCondition==2 }
        default:
            break
        }
        
        if showedItems?.isEmpty == true {
            showedItems = nil
        }
        showedItemsObservor.value = showedItems
    }
    
    func updateSavedItems(items: [Item]?) {
        if let items {
            if items.isEmpty {
                savedItemsObservor.value = nil
                FileMgr.shared.removeItems()
            } else {
                savedItemsObservor.value = items
                saveItems(items: items)
            }
        } else {
            savedItemsObservor.value = nil
            FileMgr.shared.removeItems()
        }
    }
    
    private func saveItems(items: [Item]) {
        FileMgr.shared.saveItems(items)
    }
    
    func updateItemInfo(showedItemIndex: Int, item: Item) {
        if let savedItems = savedItemsObservor.value,
           let showedItems = showedItemsObservor.value {
            var newSavesItems = savedItems
            if let chosenItemIndex = savedItems.firstIndex(where:{ $0.timeStamp == showedItems[showedItemIndex].timeStamp }){
                let oldItem = newSavesItems[chosenItemIndex]
                newSavesItems[chosenItemIndex] = item
                updateSavedItems(items: newSavesItems)
                
                // 重新設定通知
                notificationDelegate?.removeNotifications(for: oldItem)
                notificationDelegate?.rescheduleNotification(for: item)
            }
        }
    }
    
    func removeItem(showedItemIndex: Int) {
        if var savedItems = savedItemsObservor.value,
           var showedItems = showedItemsObservor.value {
            let removedItem = showedItems.remove(at: showedItemIndex)
            if let chosenItemIndex = savedItems.firstIndex(where:{ $0.timeStamp == removedItem.timeStamp }) {
                savedItems.remove(at: chosenItemIndex)
                itemModifyStatus = .deletItem(index: showedItemIndex)
                updateSavedItems(items: savedItems)
                
                // 清除被刪除物品的通知
                notificationDelegate?.removeNotifications(for: removedItem)
            }
        }
    }
    
    func addItem(item: Item) {
        var newSavedItems: [Item] = []
        if let savedItems = savedItemsObservor.value {
            newSavedItems = savedItems
        }
        newSavedItems.insert(item, at: 0)
        itemModifyStatus = .addItem
        updateSavedItems(items: newSavedItems)
        
        // 為新添加的物品安排通知
        notificationDelegate?.rescheduleNotification(for: item)
    }
    
    func resetItemStatus() {
        itemModifyStatus = .none
    }
    
}
