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
    
    func fetchedTags() {
        let defaultTags = ["蔬菜","水果","肉類","魚類"]
        let fetchTags = TagMgr.shared.fetchTags()
        if let fetchTags {
            tagsObservor.value = fetchTags
        } else {
            tagsObservor.value = defaultTags
        }
    }
    
    func setCurrentTag(tag: String?) {
        chosenTagObservor.value = tag
        print("currentTag:\(tag)")
    }
}
