//
//  SubscriptionManager.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/11.
//
//  職責：向 CloudKit 註冊 silent push 訂閱
//  - subscribeToPrivateZone：訂閱 privateDB 的 ShareZone，讓 Owner 跨裝置即時同步
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
    private let zoneSubscription: CKRecordZoneSubscription
    private let dbSubscription: CKDatabaseSubscription

    init(zoneID: CKRecordZone.ID, privateDB: CKDatabase, sharedDB: CKDatabase) {
        self.sharedDB = sharedDB
        self.privateDB = privateDB
        self.zoneSubscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: CKSubscription.ID("zoneSubscription"))
        self.dbSubscription = CKDatabaseSubscription(subscriptionID: CKSubscription.ID("dbSubscription"))
    }

    private func subscribeToPrivateZone() async throws {
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        zoneSubscription.notificationInfo = info
        try await privateDB.save(zoneSubscription)
    }

    private func subscribeToSharedDatabase() async throws {
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        dbSubscription.notificationInfo = info
        try await sharedDB.save(dbSubscription)
    }

    func subscribe() async throws {
        try await subscribeToPrivateZone()
        try await subscribeToSharedDatabase()
    }

    func unsubscribeFromShared() async throws {
        try await sharedDB.deleteSubscription(withID: dbSubscription.subscriptionID)
    }
}
