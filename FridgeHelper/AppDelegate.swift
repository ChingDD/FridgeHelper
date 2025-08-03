//
//  AppDelegate.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import UIKit
import UserNotifications
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    let backgroundTaskID = "com.jefflin.FridgeHelper.checkExpired"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //sleep(3)
        print("家目錄：\(NSHomeDirectory())")
        //Set Navigation UI
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        navigationBarAppearance.shadowColor = .clear
        let font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        navigationBarAppearance.titleTextAttributes = [
            .font : font,
            .foregroundColor : UIColor(named: "Color6")!
        ]
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        planAllItemsExpirationNotification()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    //當user點通知時會執行的程式碼
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        center.setBadgeCount(0) //清除Badge數量
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner ,.sound])    //當app在前景時，也可以跳出通知(這邊取消icon數字的呈現)
    }

    // MARK: - User Notifications

    // 清除特定物品的所有通知
    func removeNotifications(for item: Item) {
        let center = UNUserNotificationCenter.current()
        let identifiers = [
            "three-days-\(item.name)-\(item.timeStamp ?? "")",
            "expiry-day-\(item.name)-\(item.timeStamp ?? "")"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Removed notifications for item: \(item.name)")
    }
    
    // 為單一物品安排通知
    func scheduleNotification(for item: Item) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()
        
        let expiryDate = item.expiryDate
        let daysUntilExpiry = calendar.dateComponents([.day], from: now, to: expiryDate).day ?? 0
        
        // 只為未過期的物品安排通知
        if daysUntilExpiry >= 0 {
            
            // 1. 安排過期前三天的通知
            if daysUntilExpiry >= 3 {
                let threeDaysContent = UNMutableNotificationContent()
                threeDaysContent.title = "食物即將過期"
                threeDaysContent.body = "\(item.name) 還有3天過期，記得及時處理！"
                threeDaysContent.sound = .default
                threeDaysContent.userInfo = ["item-name": item.name, "expiry-date": item.expiryDate, "notification-type": "three-days-before"]
                
                let threeDaysBeforeExpiry = calendar.date(byAdding: .day, value: -3, to: expiryDate)!
                let threeDaysComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: threeDaysBeforeExpiry)
                
                let threeDaysTrigger = UNCalendarNotificationTrigger(dateMatching: threeDaysComponents, repeats: false)
                let threeDaysRequest = UNNotificationRequest(
                    identifier: "three-days-\(item.name)-\(item.timeStamp ?? UUID().uuidString)",
                    content: threeDaysContent,
                    trigger: threeDaysTrigger
                )
                
                center.add(threeDaysRequest) { error in
                    if let error = error {
                        print("Error scheduling 3-day notification for \(item.name): \(error)")
                    } else {
                        print("3-day notification scheduled for \(item.name)")
                    }
                }
            }
            
            // 2. 安排過期當天的通知
            let expiryDayContent = UNMutableNotificationContent()
            expiryDayContent.title = "食物今天過期！"
            expiryDayContent.body = "\(item.name) 今天過期，請立即處理！"
            expiryDayContent.sound = .default
            expiryDayContent.userInfo = ["item-name": item.name, "expiry-date": item.expiryDate, "notification-type": "expiry-day"]
            
            let expiryDayComponents = calendar.dateComponents([.year, .month, .day], from: expiryDate)
            let expiryDayTrigger = UNCalendarNotificationTrigger(dateMatching: expiryDayComponents, repeats: false)
            let expiryDayRequest = UNNotificationRequest(
                identifier: "expiry-day-\(item.name)-\(item.timeStamp ?? UUID().uuidString)",
                content: expiryDayContent,
                trigger: expiryDayTrigger
            )
            
            center.add(expiryDayRequest) { error in
                if let error = error {
                    print("Error scheduling expiry-day notification for \(item.name): \(error)")
                } else {
                    print("Expiry-day notification scheduled for \(item.name)")
                }
            }
        }
    }
    
    func planAllItemsExpirationNotification() {
        let items = FileMgr.shared.fetchItems()
        guard let items, !items.isEmpty else { return }

        for item in items {
            scheduleNotification(for: item)
        }
    }
}

