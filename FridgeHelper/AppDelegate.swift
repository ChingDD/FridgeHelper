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
    var sharedStack: SwiftDataStack?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Create SwiftData Container
        do {
            sharedStack = try SwiftDataStack()
        } catch {
            fatalError("SwiftData 初始化失敗: \(error)")
        }

        // Sync Cloud Data To Local
        // Plan Notification
        Task {
            do {
                try await syncCloudToLocal()
                planAllItemsExpirationNotification()
            } catch {
                printInfo("Sync Cloud To Local Fail: \(error)")
            }
        }


        // Set delegate before requesting authorization
        /*
         為了要觸發以下兩個 delegate
         1. willPresent：若沒有設定 delegate，App 在前景時收到的通知會被系統靜默丟棄，不會顯示 banner。
         2. didReceive：使用者點通知時的回調，沒有 delegate 就不會觸發。
         */
        UNUserNotificationCenter.current().delegate = self

        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error { print("Notification authorization error: \(error)") }
            print("Notification permission granted: \(granted)")
        }

        // Registers to receive remote notifications
        application.registerForRemoteNotifications()

        // Subscribe Cloud Database
        let zoneMgr = ZoneManager()
        let cloudDB = CloudRepository(zoneMgr: zoneMgr)
        let subscriptionMgr = SubscriptionManager(zoneID: zoneMgr.zoneID,
                                                  privateDB: cloudDB.privateDatabase,
                                                  sharedDB: cloudDB.sharedDatabase)
        Task {
            do {
                try await zoneMgr.ensureZoneExists()
                try await subscriptionMgr.subscribe()
            } catch {
                printInfo("Subscribe Cloud Database Fail: \(error)")
            }
        }

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
    
    // 為單一物品安排通知（供外部直接傳入 Item 物件時使用）
    func scheduleNotification(for item: Item) {
        scheduleNotification(name: item.name, timeStamp: item.timeStamp, expiryDate: item.expiryDate)
    }

    // 實際安排通知的核心方法，接受值型別，避免 SwiftData ModelContext 釋放後 crash
    private func scheduleNotification(name: String, timeStamp: String?, expiryDate: Date) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()

        let daysUntilExpiry = calendar.dateComponents([.day], from: now, to: expiryDate).day ?? 0

        // 只為未過期的物品安排通知
        if daysUntilExpiry >= 0 {

            // 1. 安排過期前三天的通知
            if daysUntilExpiry >= 3 {
                let threeDaysContent = UNMutableNotificationContent()
                threeDaysContent.title = "食物即將過期"
                threeDaysContent.body = "\(name) 還有3天過期，記得及時處理！"
                threeDaysContent.sound = .default
                threeDaysContent.userInfo = ["item-name": name, "expiry-date": expiryDate, "notification-type": "three-days-before"]

                let threeDaysBeforeExpiry = calendar.date(byAdding: .day, value: -3, to: expiryDate)!
                let threeDaysComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: threeDaysBeforeExpiry)

                let threeDaysTrigger = UNCalendarNotificationTrigger(dateMatching: threeDaysComponents, repeats: false)
                let threeDaysRequest = UNNotificationRequest(
                    identifier: "three-days-\(name)-\(timeStamp ?? UUID().uuidString)",
                    content: threeDaysContent,
                    trigger: threeDaysTrigger
                )

                center.add(threeDaysRequest) { error in
                    if let error = error {
                        print("Error scheduling 3-day notification for \(name): \(error)")
                    } else {
                        print("3-day notification scheduled for \(name)")
                    }
                }
            }

            // 2. 安排過期當天的通知
            let expiryDayContent = UNMutableNotificationContent()
            expiryDayContent.title = "食物今天過期！"
            expiryDayContent.body = "\(name) 今天過期，請立即處理！"
            expiryDayContent.sound = .default
            expiryDayContent.userInfo = ["item-name": name, "expiry-date": expiryDate, "notification-type": "expiry-day"]

            let expiryDayComponents = calendar.dateComponents([.year, .month, .day], from: expiryDate)
            let expiryDayTrigger = UNCalendarNotificationTrigger(dateMatching: expiryDayComponents, repeats: false)
            let expiryDayRequest = UNNotificationRequest(
                identifier: "expiry-day-\(name)-\(timeStamp ?? UUID().uuidString)",
                content: expiryDayContent,
                trigger: expiryDayTrigger
            )

            center.add(expiryDayRequest) { error in
                if let error = error {
                    print("Error scheduling expiry-day notification for \(name): \(error)")
                } else {
                    print("Expiry-day notification scheduled for \(name)")
                }
            }
        }
    }
    
    private func planAllItemsExpirationNotification() {
        guard let stack = sharedStack else { return }
        Task { @MainActor in
            guard let items = try? await SwiftDataItemRepository(container: stack.container).fetch(),
                  !items.isEmpty else { return }
            // 在 ModelContext 還有效時，先將值型別資料複製出來，避免 context 釋放後 crash
            let snapshots = items.map { (name: $0.name, timeStamp: $0.timeStamp, expiryDate: $0.expiryDate) }
            for snapshot in snapshots {
                self.scheduleNotification(name: snapshot.name, timeStamp: snapshot.timeStamp, expiryDate: snapshot.expiryDate)
            }
        }
    }

    func syncCloudToLocal(shouldNotifyChanges: Bool = false) async throws {
        guard let stack = sharedStack else { return }
        let syncMgr = SyncCoordinator(localRepository: SwiftDataItemRepository(container: stack.container),
                                      zoneMgr: ZoneManager())

        let changes = try await syncMgr.fetchChanges()
        if shouldNotifyChanges {
            notifyCloudChanges(changes)
        }
        NotificationCenter.default.post(name: .cloudKitDataDidChange, object: nil)
    }

    private func notifyCloudChanges(_ changes: [CloudItemChange]) {
        let groupedChanges = Dictionary(grouping: changes) { $0.updatedByName ?? "其他設備" }

        for (updater, changes) in groupedChanges {
            guard let firstItemName = changes.first?.itemName else { continue }

            let content = UNMutableNotificationContent()
            content.title = "冰箱資料已更新"
            content.body = changes.count == 1
                ? "\(updater) 更新了 \(firstItemName)"
                : "\(updater) 更新了 \(firstItemName) 等 \(changes.count) 個物品"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "cloud-change-\(updater)-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}

extension Notification.Name {
    static let cloudKitDataDidChange = Notification.Name("cloudKitDataDidChange")
}

// Remote Notification
extension AppDelegate {
    @MainActor
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        guard userInfo["ck"] != nil else { return .noData }
        
        do {
            try await syncCloudToLocal(shouldNotifyChanges: true)
            return .newData
        } catch {
            printInfo("Sync Cloud To Local Fail: \(error)")
            return .failed
        }
    }
}
