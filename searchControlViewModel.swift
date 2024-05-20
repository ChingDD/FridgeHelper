//
//  searchControlViewModel.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/5/19.
//

import Foundation

class SearchControlViewModel {
    var keywordObservor: ObservableObject = ObservableObject<String?>(value: nil)
    
    func setKeyword(_ keyword: String?) {
        keywordObservor.value = keyword
    }
}

