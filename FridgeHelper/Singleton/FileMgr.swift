//
//  ItemHelper.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/5/18.
//

import Foundation
import UIKit

class FileMgr {
    
    static let shared = FileMgr()
    
    func saveImage(_ item: Item, image: UIImage){
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
    func loadImage(_ item: Item)->UIImage?{
        
        let url = URL.documentsDirectory.appending(path: item.name)
        guard let image = UIImage(contentsOfFile: url.path().removingPercentEncoding ?? "") else{ return nil }
        return image
        
    }
    
    
    //移除儲存的圖片
    func removeImage( _ item: Item){
        
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
    func fetchItems()->[Item]?{
        
        let url = URL.documentsDirectory.appending(path: "items")
        print("url:\(url)")
        if let itemData = try? Data(contentsOf: url){
            let items = try! JSONDecoder().decode([Item].self, from: itemData)
            print("Fetch Items Success")
            return items
        }
        print("Fetch Items Fail")
        return nil
        
    }
    
    func fetchExpiredItems(_ savedItems: [Item]?) -> [Item]? {
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
    func saveItems(_ items:[Item]){
        
        if let itemData = try? JSONEncoder().encode(items){
            let url = URL.documentsDirectory.appending(path: "items")
            try? itemData.write(to: url)
            print("Save Items Success")
        }
    }
    
    func removeItems() {
        let url = URL.documentsDirectory.appending(path: "items")
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("remove items file fail")
        }
    }
    
    //Tag
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
    
    func removeTags() {
        let url = URL.documentsDirectory.appending(path: "tags")
        do {
            try FileManager.default.removeItem(at: url)
            print("Remove Tags File Success")
        } catch {
            print("Remove Tags File Fail")
        }
    }
}

