//
//  DataController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/7.
//

import Foundation
import UIKit
class dateController {
    static let shared = dateController()
    
    let datePicker = UIDatePicker()
    func createDatePicker()->UIDatePicker{
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        //滾輪呈現/日曆資訊的時間顯示是以台灣習慣為主的語言(但時區不變)
        datePicker.locale = Locale(identifier: "zh-TW")
        //過去的時間可選30天前
        datePicker.minimumDate = Date(timeIntervalSinceNow: -2592000)
        //背景
        datePicker.backgroundColor = UIColor(named: "Color7")
        datePicker.date = Date()
        //這時print出來的是倫敦的時區，因為這個func沒有用dateFormatter改時區
        datePicker.addTarget(self, action: #selector(printDate), for: .valueChanged)
        return datePicker
    }
    
    
    @objc func printDate() {
        //這時print出來的是倫敦的時區
        //print(datePicker.date)
    }
    
    func setDateFormate(_ date:Date) -> String{
        let dateFormatter = DateFormatter()
        //呈現在textField上的字串為中文格式
        //dateFormatter.locale = Locale(identifier: "zh-TW")
        //時區變成台北
        //dateFormatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        dateFormatter.dateFormat = "YYYY/MM/dd EEEE"
        printInfo(dateFormatter.string(from: date))
       return dateFormatter.string(from: date)
    }
    
    func creatItemTimeStamp() -> String {
        let date = Date()
        let timeStamp = date.timeIntervalSince1970
        let stringTimeStamp = String(timeStamp)
        
        return stringTimeStamp
    }
}
