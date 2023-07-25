//
//  alertVIew.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/6.
//

import Foundation
import UIKit

class AlertViewController{
    static let Constants:CGFloat = 0.6
    
    let backgroundView:UIView = {
       let backgroundView = UIView()
        backgroundView.backgroundColor = .black
        backgroundView.alpha = 0
        return backgroundView
    }()
    
    let alertView:UIView = {
        let alertView = UIView()
        alertView.layer.masksToBounds = true
        alertView.layer.cornerRadius = 15
        alertView.backgroundColor = .white
        return alertView
     }()
    
    var myTargetView:UIView?
    
    func showAlert(title:String, message:String, on controller:UIViewController){
        
    }
    
    
    
    
}
