//
//  File.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/5/17.
//

import Foundation

class TagViewModel {
    var tagsObservor: ObservableObject = ObservableObject<[String]?>(value: nil)
    var chosenTagObservor: ObservableObject = ObservableObject<String?>(value: nil)
    var tagModifyStatus: ItemModifyStatus = .none
    
    func fetchedTags() {
        let defaultTags = ["蔬菜","水果","肉類","魚類"]
        let fetchTags = FileMgr.shared.fetchTags()
        if let fetchTags {
            if fetchTags.isEmpty {
                tagsObservor.value = []
            }
            tagsObservor.value = fetchTags
        } else {
            tagsObservor.value = defaultTags
        }
    }
    
     func updateTags(tags: [String]?) {
        tagsObservor.value = tags
        FileMgr.shared.saveTags(tags: tags)
    }
    
    func setCurrentTag(tag: String?) {
        chosenTagObservor.value = tag
    }
    
    func resetTagModifyStatus() {
        tagModifyStatus = .none
    }
}
