//
//  SortMethod.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/14.
//

import Foundation
import UIKit

enum SortMethod:String, CaseIterable{
    case 取消
    case 時間排序遠到近 = "時間排序－遠到近"
    case 時間排序近到遠 = "時間排序－近到遠"
    case 剩餘數量多到少 = "剩餘數量－多到少"
    case 剩餘數量少到多 = "剩餘數量－少到多"
    
    func sortShowedItems( _ Items:[Item]?)->[Item]?{
        switch self{
        case .取消:
            return Items
        case .時間排序遠到近:
            let showedItems = Items?.sorted(by: { $0.expiryDate < $1.expiryDate })
            return showedItems
        case .時間排序近到遠:
            let showedItems = Items?.sorted(by: { $0.expiryDate > $1.expiryDate })
            return showedItems
        case .剩餘數量多到少:
            let showedItems =  Items?.sorted(by: { $0.number > $1.number })
            return showedItems
        case .剩餘數量少到多:
            let showedItems = Items?.sorted(by: { $0.number < $1.number })
            return showedItems
        }
    }
}

