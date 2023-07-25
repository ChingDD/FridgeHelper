//
//  DataController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/7.
//

import Foundation
import UIKit
class dateController{
    static let share = dateController()
    let datePicker = UIDatePicker()
    func createDatePicker()->UIDatePicker{
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        //滾輪呈現的時間顯示是英文
        datePicker.locale = Locale(identifier: "en_US")
        datePicker.date = Date()
        //這時print出來的是倫敦的時區，因為這個func沒有用dateFormatter改時區
        datePicker.addTarget(self, action: #selector(printDate), for: .valueChanged)
        return datePicker
    }
    
    
    @objc func printDate(){
        print(datePicker.date)
    }
    
    func setDateFormate(_ date:Date)->String{
        let dateFormatter = DateFormatter()
        //呈現在textField上的字串為英文
        dateFormatter.locale = Locale(identifier: "en_US")
        //時區變成台北

        dateFormatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        dateFormatter.dateFormat = "E, MMM d, yyyy"
       return dateFormatter.string(from: date)
    }
}
