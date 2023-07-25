//
//  TagController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/6.
//

import Foundation
import UIKit

class TagController{
    static let shared = TagController()
    
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
    
    
    func updateClickUI(_ button:UIButton ,currentTag:String?){
        if let currentTag{
            button.menu?.children.forEach {
                let tagAction = $0 as! UIAction
                if tagAction.title == currentTag{
                    tagAction.state = .on
                }
            }
        }
    }
    
    
    
}
