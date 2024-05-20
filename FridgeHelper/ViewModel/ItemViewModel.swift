//
//  LunchingViewModel.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/4/10.
//

import Foundation

class ItemViewModel {
    var savedItemsObservor: ObservableObject = ObservableObject<[Item]?>(value: nil)
    var expiredItemObservor: ObservableObject = ObservableObject<[Item]?>(value: nil)
    var showedItemsObservor: ObservableObject = ObservableObject<[Item]?>(value: nil)
    
//    var showedItems: [Item]?
//    var savedItems: [Item]? {
//        didSet {
//            if let savedItems {
//                Item.saveItems(savedItems)
//                print("savedItems已更新")
//            } else {
//                let url = URL.documentsDirectory.appending(path: "items")
//                let fileManager = FileManager.default
//                do {
//                    try fileManager.removeItem(at: url)
//                } catch {
//                    print("items移除失敗")
//                }
//            }
//        }
//    }
//    var expiredItems: [Item]?
//    var isHideExpireLabel: Bool = true
//    var expiredItemNumber: String = ""
    
    //接收第二頁傳過來的item
    var item: Item?
    
    //搜尋列
    var searchingItems:[Item]?
    var keyword = ""


    init() {
        //讀取存在Document資料夾的items
        savedItemsObservor.value = ItemHelper.fetchItems()
        showedItemsObservor.value = ItemHelper.fetchItems()
    }
    
    func fetchSavedItems() {
        let items = ItemHelper.fetchItems()
        showedItemsObservor.value = items
    }
    
    func fetchExpiredItems() {
//        //抓出有過期的物品
//        let expiredItems = savedItems?.filter({
//            $0.expiryDate.timeIntervalSinceNow <= 259200
//        })
//        //如果過濾完結果是空字串，就設回nil，否則就顯示警示Label個數
//        if let expiredItems {
//            if expiredItems.isEmpty {
//                isHideExpireLabel = true
//                self.expiredItems = nil
//            } else {
//                isHideExpireLabel = false
//                expiredItemNumber = "\(expiredItems.count)"
//            }
//        }
        let items = ItemHelper.fetchExpiredItems(savedItemsObservor.value)
        expiredItemObservor.value = items
    }
    
    func searchKeywords(_ inputText: String?, items: [Item]?)->[Item]? {
        guard let items else { return nil }
        guard let inputText, !inputText.isEmpty else { return items }
        
        let result = items.filter({ $0.name.contains(inputText) })
        
        if result.isEmpty {
            return nil  //沒篩到東西
        } else {
            return result   //有篩到東西
        }
        
    }
    
    func selectedTagItems(currentTag: String? = nil, items: [Item]?) -> [Item]? {
        guard let items else { return nil }
        guard let currentTag else { return items }
        
        let selectedTagItems = items.filter({ $0.tag == currentTag})
        if selectedTagItems.isEmpty {
            return nil
        } else {
            return selectedTagItems
        }
    }
    
    func updateShowedItems(SegmentControllerIndex: Int,  sortOption: SortMethod, tag: String?, keyword: String?){
        let savedItems = savedItemsObservor.value
        var showedItems: [Item]?
        showedItems = sortOption.sortShowedItems(savedItems)
        showedItems = searchKeywords(keyword, items: showedItems)
        showedItems = selectedTagItems(currentTag: tag, items: showedItems)
        switch SegmentControllerIndex {
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
                ItemHelper.removeItemsFile()
            } else {
                savedItemsObservor.value = items
                saveItems(items: items)
            }
        } else {
            savedItemsObservor.value = nil
            ItemHelper.removeItemsFile()
        }
    }
    
    private func saveItems(items: [Item]) {
        ItemHelper.saveItems(items)
    }
    
    func updateItemInfo(showedItemIndex: Int, item: Item) {
        if let savedItems = savedItemsObservor.value,
           let showedItems = showedItemsObservor.value {
            var newSavesItems = savedItems
            if let chosenItemIndex = savedItems.firstIndex(where:{ $0.name == showedItems[showedItemIndex].name && $0.expiryDate == showedItems[showedItemIndex].expiryDate }){
                newSavesItems[chosenItemIndex] = item
                updateSavedItems(items: newSavesItems)
            }
        }
    }
    
    func removeItem(showedItemIndex: Int) {
        if var savedItems = savedItemsObservor.value,
           var showedItems = showedItemsObservor.value {
            let removedItem = showedItems.remove(at: showedItemIndex)
            if let chosenItemIndex = savedItems.firstIndex(where:{ $0.name == removedItem.name && $0.expiryDate == removedItem.expiryDate }){
                savedItems.remove(at: chosenItemIndex)
                updateSavedItems(items: savedItems)
            }
        }
    }
}
