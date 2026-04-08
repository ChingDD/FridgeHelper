//
//  item.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import Foundation
import UIKit
import SwiftData

enum StoreCondition {
    case 室溫
    case 冷藏
    case 冷凍

    func StoreConditionSegementIndex()->Int{
        switch self{
        case .室溫: return 0
        case .冷藏: return 1
        case .冷凍: return 2
        }
    }
}

@Model
class Item {
    var name: String = ""
    var number: Int = 0
    var expiryDate: Date = Date()
    var storeCondition: Int = 0
    var memo: String?
    var tag: String?
    @Attribute(.externalStorage) var image: Data?
    var timeStamp: String?

    init(name: String, number: Int, expiryDate: Date, storeCondition: Int, memo: String? = nil, tag:   String? = nil, image: Data? = nil, timeStamp: String? = nil) {
        self.name = name
        self.number = number
        self.expiryDate = expiryDate
        self.storeCondition = storeCondition
        self.memo = memo
        self.tag = tag
        self.image = image
        self.timeStamp = timeStamp
    }
}


