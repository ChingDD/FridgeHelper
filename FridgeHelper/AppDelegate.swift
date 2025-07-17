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
        
        //Set UNUserNotificationCenter and request authorization
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            if granted {
                print("Notification authorization granted.")
            } else {
                print("Notification authorization denied.")
            }
        }
        
        // Register the background task
        registerBackgroundTask()
        
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
    
    // MARK: - Background Task Management
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskID, using: nil) { task in
            // This closure is called when the system runs the task
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        
        // Set the earliest time to run the task to 8:00 AM
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        
        // For production, schedule for the next 8 AM
        let now = Date()
        var eightAM = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        if eightAM < now {
            // If 8 AM has already passed today, schedule for tomorrow
            eightAM = Calendar.current.date(byAdding: .day, value: 1, to: eightAM)!
        }
        request.earliestBeginDate = eightAM

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled successfully for \(request.earliestBeginDate!)")
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh task so it repeats
        scheduleAppRefresh()

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operation = BlockOperation {
            print("Performing background fetch...")
            let items = FileMgr.shared.fetchItems()
            if let expiredItems = FileMgr.shared.fetchExpiredItems(items), !expiredItems.isEmpty {
                self.sendExpirationNotification(expiredItems: expiredItems)
            }
        }

        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        operation.completionBlock = {
            let success = !operation.isCancelled
            print("Background fetch completed with success: \(success)")
            task.setTaskCompleted(success: success)
        }

        queue.addOperation(operation)
    }

    // MARK: - User Notifications
    func sendExpirationNotification(expiredItems: [Item]) {
        let content = UNMutableNotificationContent()
        content.title = "冰箱裡有東西快過期囉！"
        content.body = "有 \(expiredItems.count) 樣物品即將過期，快去看看吧！"
        content.sound = .default
        content.userInfo = ["show-expired-items": true] // Custom data

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            } else {
                print("Notification sent successfully for \(expiredItems.count) items.")
            }
        }
    }
}

