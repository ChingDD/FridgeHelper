//
//  ItemHelper.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/5/18.
//

import Foundation
import UIKit

class ItemHelper {
    
    static func saveImage(_ item: Item, image: UIImage){
        //用JPG存檔，他的Orientation才不會消失
        if let imageData = image.jpegData(compressionQuality: 1){
            
            let direction = image.imageOrientation
            print("存照片前的方向:\(direction)")
            let url = URL.documentsDirectory.appending(path: item.name)
            do{
                try imageData.write(to: url)
                
                print("寫入成功")
            }catch{
                print("照片寫入失敗")
            }
            
        }

    }
    
    //讀取照片
    static func loadImage(_ item: Item)->UIImage?{
        
        let url = URL.documentsDirectory.appending(path: item.name)
        guard let image = UIImage(contentsOfFile: url.path().removingPercentEncoding ?? "") else{ return nil }
        return image
        
    }
    
    
    //移除儲存的圖片
    static func removeImage( _ item: Item){
        
        let url = URL.documentsDirectory.appending(path: item.name)
        let fileManager = FileManager.default
        do{
            try fileManager.removeItem(at: url)
            print("圖片移除成功")
        }catch{
            print("圖片移除失敗")
        }
        
    }
    
    //抓物品
    static func fetchItems()->[Item]?{
        
        let url = URL.documentsDirectory.appending(path: "items")
        print("url:\(url)")
        if let itemData = try? Data(contentsOf: url){
            let items = try! JSONDecoder().decode([Item].self, from: itemData)
            return items
        }
        return nil
        
    }
    
    static func fetchExpiredItems(_ savedItems: [Item]?) -> [Item]? {
        //抓出有過期的物品
        let expiredItems = savedItems?.filter({
            $0.expiryDate.timeIntervalSinceNow <= 259200
        })
        //如果過濾完結果是空字串，就設回nil，否則就顯示警示Label個數
        if let expiredItems {
            if expiredItems.isEmpty {
                return nil
            } else {
                return expiredItems
            }
        }
        return nil
    }
    
    
    //將item變成Data存在Document資料夾
    static func saveItems(_ items:[Item]){
        
        if let itemData = try? JSONEncoder().encode(items){
            let url = URL.documentsDirectory.appending(path: "items")
            try? itemData.write(to: url)
        }
    }
    
    static func removeItemsFile() {
        let url = URL.documentsDirectory.appending(path: "items")
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("remove items file fail")
        }
    }
}

