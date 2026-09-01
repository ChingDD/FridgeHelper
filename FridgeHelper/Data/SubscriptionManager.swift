//
//  SubscriptionManager.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/11.
//
//  職責：向 CloudKit 註冊 silent push 訂閱
//  - subscribeToPrivateDatabase：訂閱 privateDB，讓 Owner 跨裝置即時同步
//  - subscribeToSharedDatabase：訂閱 sharedDB，讓 Participant 收到 Owner 的更新
//  - 收到 silent push 後由 AppDelegate 觸發 SyncCoordinator.fetchChanges()

import Foundation
import CloudKit

protocol Subscribable {
    func subscribe() async throws
    func unsubscribeFromShared() async throws
}

class SubscriptionManager: Subscribable {
    let sharedDB: CKDatabase
    let privateDB: CKDatabase
    private let privateDBSubscription: CKDatabaseSubscription
    private let sharedDBSubscription: CKDatabaseSubscription

    /// 多冰箱之前 privateDB 只訂閱固定那一座 zone，之後新增的 zone 收不到 silent push
    private static let legacyZoneSubscriptionID = CKSubscription.ID("zoneSubscription")

    init(privateDB: CKDatabase, sharedDB: CKDatabase) {
        self.sharedDB = sharedDB
        self.privateDB = privateDB
        self.privateDBSubscription = CKDatabaseSubscription(subscriptionID: CKSubscription.ID("privateDBSubscription"))
        self.sharedDBSubscription = CKDatabaseSubscription(subscriptionID: CKSubscription.ID("dbSubscription"))
    }

    private func subscribeToPrivateDatabase() async throws {
        privateDBSubscription.notificationInfo = makeSilentNotificationInfo()
        try await privateDB.save(privateDBSubscription)
    }

    private func subscribeToSharedDatabase() async throws {
        sharedDBSubscription.notificationInfo = makeSilentNotificationInfo()
        try await sharedDB.save(sharedDBSubscription)
    }

    /// 舊的 zone 訂閱留著只會讓同一次變更多推一次，同步結果不變但白花電量
    private func removeLegacyZoneSubscription() async {
        _ = try? await privateDB.deleteSubscription(withID: Self.legacyZoneSubscriptionID)
    }

    private func makeSilentNotificationInfo() -> CKSubscription.NotificationInfo {
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        return info
    }

    func subscribe() async throws {
        try await subscribeToPrivateDatabase()
        try await subscribeToSharedDatabase()
        await removeLegacyZoneSubscription()
    }

    func unsubscribeFromShared() async throws {
        try await sharedDB.deleteSubscription(withID: sharedDBSubscription.subscriptionID)
    }
}
