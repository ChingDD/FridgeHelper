//
//  segmentationControllerViewModel.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/5/19.
//

import Foundation

class SegmentationControlViewModel {
    var indexObservor: ObservableObject = ObservableObject<Int>(value: 0)
    
    func setIndex(index: Int) {
        indexObservor.value = index
    }
}
