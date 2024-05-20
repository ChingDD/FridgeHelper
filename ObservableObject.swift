//
//  ObservableObject.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/5/16.
//

import Foundation

class ObservableObject <T> {
    var value: T {
        didSet {
            listener?(value)
        }
    }
    
    var listener: ((T) -> Void)?
    
    init(value: T) {
        self.value = value
    }
    
    func bind(_ listener: @escaping ((T) -> Void)) {
        listener(value)
        self.listener = listener
    }
}
