//
//  MainTabBarFactory.swift
//  FridgeHelper
//
//  依選定的冰箱組裝 Repository / ViewModel / MainTabBarController。
//  每次選擇冰箱都會得到綁定該冰箱的全新 ViewModel，不會殘留上一座冰箱的狀態
//

import UIKit
import SwiftData

@MainActor
enum MainTabBarFactory {

    static func make(fridge: Fridge, stack: SwiftDataStack) -> MainTabBarController {
        let context = stack.container.mainContext
        let localRepo = SwiftDataItemRepository(container: stack.container)
        let cloudRepo = CloudRepository(zoneMgr: ZoneManager())
        let compositeRepo = CompositeRepository(local: localRepo, cloud: cloudRepo)

        // 清單編輯後上傳（Owner 寫完整 metadata，成員只寫清單欄位）
        let pushMetadata: () -> Void = {
            Task { @MainActor in
                do {
                    try await FridgeMetadataRepository(zoneMgr: ZoneManager()).upsert(for: fridge)
                } catch {
                    printInfo("FridgeMetadata 上傳失敗: \(error)")
                }
            }
        }
        let tagListViewModel = StringListViewModel(
            store: FridgeStringListStore(fridge: fridge, keyPath: \.tags, context: context, onChange: pushMetadata),
            defaults: FridgeListDefaults.tags
        )
        let locationListViewModel = StringListViewModel(
            store: FridgeStringListStore(fridge: fridge, keyPath: \.locations, context: context, onChange: pushMetadata),
            defaults: FridgeListDefaults.locations
        )
        let mainViewModel = MainViewModel(
            fridge: fridge,
            tags: tagListViewModel,
            locations: locationListViewModel,
            local: compositeRepo,
            // 階段四完成 StoreKit 後，改注入依購買權益判斷的實作
            planProvider: FreeFridgePlanProvider(),
            syncFromCloud: {
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                try await appDelegate.syncCloudToLocal()
            }
        )

        let fridgeVC = FridgeViewController()
        fridgeVC.viewModel = mainViewModel

        // 共享是逐冰箱的，ShareManager 綁在選定的那座冰箱上
        let participantsVC = ParticipantsViewController()
        participantsVC.viewModel = ParticipantsViewModel(
            shareManager: ShareManager(fridge: fridge, zoneMgr: ZoneManager())
        )

        let tabBarController = MainTabBarController()
        tabBarController.setViewControllers([
            UINavigationController(rootViewController: fridgeVC),
            UINavigationController(rootViewController: ScanViewController()),
            UINavigationController(rootViewController: participantsVC),
        ], animated: false)
        return tabBarController
    }
}
