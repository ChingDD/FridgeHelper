//
//  LunchingViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/18.
//
//  組合根：建立 Repository / ViewModel，啟動動畫後切換到 MainTabBarController

import UIKit
import SwiftData

class LunchingViewController: UIViewController {

    var launchScreen: UIViewController?

    // Shared ViewModel instances — created once here and injected down the stack
    private var sharedTagListViewModel: StringListViewModel!
    private var sharedLocationListViewModel: StringListViewModel!
    private var sharedMainViewModel: MainViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        configViewModel()
        setLaunchScreenImageAnimation()
    }

    private func configViewModel() {
        guard let stack = (UIApplication.shared.delegate as? AppDelegate)?.sharedStack else {
            fatalError("SharedStack 尚未初始化")
        }
        let context = stack.container.mainContext
        let fridge = selectedFridge(in: context)
        let localRepo = SwiftDataItemRepository(container: stack.container)
        let cloudRepo = CloudRepository(zoneMgr: ZoneManager())
        let compositeRepo = CompositeRepository(local: localRepo, cloud: cloudRepo)
        sharedTagListViewModel = StringListViewModel(
            store: FridgeStringListStore(fridge: fridge, keyPath: \.tags, context: context),
            defaults: FridgeListDefaults.tags
        )
        sharedLocationListViewModel = StringListViewModel(
            store: FridgeStringListStore(fridge: fridge, keyPath: \.locations, context: context),
            defaults: FridgeListDefaults.locations
        )
        sharedMainViewModel = MainViewModel(
            fridge: fridge,
            tags: sharedTagListViewModel,
            locations: sharedLocationListViewModel,
            local: compositeRepo,
            // 階段四完成 StoreKit 後，改注入依購買權益判斷的實作
            planProvider: FreeFridgePlanProvider(),
            syncFromCloud: {
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                try await appDelegate.syncCloudToLocal()
            }
        )
    }

    /// 上次選取的冰箱；找不到就退回 Default 冰箱。階段三接上冰箱選擇首頁後改由該頁決定
    private func selectedFridge(in context: ModelContext) -> Fridge {
        let fridges = (try? context.fetch(FetchDescriptor<Fridge>())) ?? []
        let defaultID = Fridge.makeID(zoneName: ZoneManager.defaultZoneName, ownerName: nil)
        let targetID = SelectedFridgeStore.fridgeID ?? defaultID

        guard let fridge = fridges.first(where: { $0.fridgeID == targetID })
                ?? fridges.first(where: { $0.fridgeID == defaultID }) else {
            // FridgeMigrator 在 didFinishLaunching 就會建立 Default 冰箱，正常不會走到這裡
            fatalError("找不到可用的冰箱，Fridge 遷移未完成")
        }
        SelectedFridgeStore.fridgeID = fridge.fridgeID
        return fridge
    }

    private func makeMainTabBarController() -> MainTabBarController {
        let fridgeVC = FridgeViewController()
        fridgeVC.viewModel = sharedMainViewModel

        let participantsVC = ParticipantsViewController()
        participantsVC.viewModel = ParticipantsViewModel(shareManager: ShareManager(zoneMgr: ZoneManager()))

        let tabBarController = MainTabBarController()
        tabBarController.setViewControllers([
            UINavigationController(rootViewController: fridgeVC),
            UINavigationController(rootViewController: ScanViewController()),
            UINavigationController(rootViewController: participantsVC),
        ], animated: false)
        return tabBarController
    }

    // MARK: - Launch Animation

    private func setLaunchScreenImageAnimation() {
        let launchStoryboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
        launchScreen = launchStoryboard.instantiateInitialViewController()
        view.addSubview(launchScreen!.view)

        guard let label = launchScreen?.view.viewWithTag(1) as? UILabel,
              let imageView = launchScreen?.view.viewWithTag(2) as? UIImageView else { return }

        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0, delay: 0, options: .allowAnimatedContent) {
            let rotationAnimate = CABasicAnimation(keyPath: "transform.rotation")
            rotationAnimate.fromValue = 0
            rotationAnimate.toValue = Double.pi * 2
            rotationAnimate.duration = 0.8
            imageView.layer.add(rotationAnimate, forKey: nil)
            printInfo("第一段動畫做完了")
        } completion: { _ in
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 1.0, delay: 0.8, options: .curveEaseInOut) {
                label.alpha = 1
                printInfo("第二段動畫做完了")
            } completion: { [weak self] _ in
                guard let self else { return }
                UIView.transition(with: self.view.window!, duration: 1, options: .transitionCrossDissolve, animations: {
                    UIView.setAnimationsEnabled(false)
                    self.view.window?.rootViewController = self.makeMainTabBarController()
                    UIView.setAnimationsEnabled(true)
                    printInfo("第三段動畫做完了")
                }, completion: nil)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {}
}
