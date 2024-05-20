//
//  item.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import Foundation
import UIKit

struct Item:Codable{
    var name:String
    var number:Int
    var expiryDate:Date
    var storeCondition:Int
    var memo:String?
    var tag:String?
    var image:Data?
    
    //存照片
    
    //    static func saveImage(_ item:Self, image:UIImage){
    //        //用JPG存檔，他的Orientation才不會消失
    //        if let imageData = image.jpegData(compressionQuality: 1){
    //            
    //            let direction = image.imageOrientation
    //            print("存照片前的方向:\(direction)")
    //            let url = URL.documentsDirectory.appending(path: item.name)
    //            do{
    //                try imageData.write(to: url)
    //                
    //                print("寫入成功")
    //            }catch{
    //                print("照片寫入失敗")
    //            }
    //            
    //        }
    //
    //    }
    //    
    //    //讀取照片
    //
    //    static func loadImage(_ item:Self)->UIImage?{
    //        
    //        let url = URL.documentsDirectory.appending(path: item.name)
    //        guard let image = UIImage(contentsOfFile: url.path().removingPercentEncoding ?? "") else{ return nil }
    //        return image
    //
    //    }
    //    
    //    
    //    //移除儲存的圖片
    //    static func removeImage( _ item:Self){
    //        
    //        let url = URL.documentsDirectory.appending(path: item.name)
    //        let fileManager = FileManager.default
    //        do{
    //            try fileManager.removeItem(at: url)
    //            print("圖片移除成功")
    //        }catch{
    //            print("圖片移除失敗")
    //        }
    //        
    //    }
    //    
    //    //抓物品
    //    static func fetchItems()->[Item]?{
    //        
    //        let url = URL.documentsDirectory.appending(path: "items")
    //        print("url:\(url)")
    //        if let itemData = try? Data(contentsOf: url){
    //            let items = try! JSONDecoder().decode([Item].self, from: itemData)
    //            return items
    //        }
    //        return nil
    //        
    //    }
    //    
    //    
    //    //將item變成Data存在Document資料夾
    //    static func saveItems(_ items:[Item]){
    //        
    //        if let itemData = try? JSONEncoder().encode(items){
    //            let url = URL.documentsDirectory.appending(path: "items")
    //            try? itemData.write(to: url)
    //        }
    //    }
    //    
    //}
    
    
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


