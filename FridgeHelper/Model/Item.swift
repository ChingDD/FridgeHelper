//
//  item.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import Foundation
import UIKit

struct Item:Codable {
    var name:String
    var number:Int
    var expiryDate:Date
    var storeCondition:Int
    var memo:String?
    var tag:String?
    var image:Data?
    var timeStamp: String
    
    enum storeCondition:String {
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
}


