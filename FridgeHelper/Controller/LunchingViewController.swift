//
//  LunchingViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/18.
//
//  組合根：建立 Repository / ViewModel，啟動動畫後切換到 MainTabBarController

import UIKit

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
        let localRepo = SwiftDataItemRepository(container: stack.container)
        let cloudRepo = CloudRepository(zoneMgr: ZoneManager())
        let compositeRepo = CompositeRepository(local: localRepo, cloud: cloudRepo)
        sharedTagListViewModel = StringListViewModel(
            store: UserDefaultsStringListStore(key: "app.swiftdata.tags"),
            defaults: ["蔬菜", "水果", "肉類", "魚類"]
        )
        sharedLocationListViewModel = StringListViewModel(
            store: UserDefaultsStringListStore(key: "app.swiftdata.storeLocations"),
            defaults: ["室溫", "冷藏", "冷凍"]
        )
        sharedMainViewModel = MainViewModel(
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
