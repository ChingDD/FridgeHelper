//
//  TagController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/6.
//

import Foundation
import UIKit

class TagMgr {
    static let shared = TagMgr()
    
    func fetchTags()->[String]?{
        let url = URL.documentsDirectory.appending(path: "tags")
        do{
            let tagsData = try Data(contentsOf: url)
            let tags = try JSONDecoder().decode([String].self, from: tagsData)
            return tags
        }catch{
            print("抓不到tags檔案")
            return nil
        }
    }
    
    func saveTags(tags:[String]?){
        let url = URL.documentsDirectory.appending(path: "tags")
        let tagsData = try! JSONEncoder().encode(tags)
        do{
            try tagsData.write(to: url)
            print("存tagsData成功")
        }catch{
            print("存取失敗")
        }
    }
    
    
//    func updateClickUI(_ button:UIButton ,currentTag:String?){
//        //只要Main畫面啟動，會預設讓cancel的按鈕勾起來
//        //如果currentTag有東西，表示還是在選擇tag的狀態，則篩選看是選到哪個tag，該tag的按鈕要勾起來
//        if let currentTag{
//            button.menu?.children.forEach {
//                let tagAction = $0 as! UIAction
//                if tagAction.title == currentTag{
//                    tagAction.state = .on
//                }
//            }
//        }
//    }
    
    
    
    
}
