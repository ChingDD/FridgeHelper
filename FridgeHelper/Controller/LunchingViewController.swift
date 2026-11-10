//
//  LunchingViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/18.
//
//  啟動動畫後切換到冰箱選擇首頁；主畫面由 MainTabBarFactory 依選定冰箱組裝

import UIKit
import SwiftData

class LunchingViewController: UIViewController {

    var launchScreen: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        setLaunchScreenImageAnimation()
    }

    /// 冰箱選擇首頁：讀取本機 Fridge，點選後以該冰箱組裝主畫面
    private func makeFridgeSelectionVC() -> UIViewController {
        guard let stack = (UIApplication.shared.delegate as? AppDelegate)?.sharedStack else {
            fatalError("SharedStack 尚未初始化")
        }
        let vc = FridgeSelectionViewController()
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        vc.viewModel = FridgeViewModel(
            context: stack.container.mainContext,
            // 階段四完成 StoreKit 後，改注入依購買權益判斷的實作
            planProvider: FreeFridgePlanProvider(),
            metadataRepository: FridgeMetadataRepository(zoneMgr: ZoneManager()),
            zoneRepository: FridgeZoneRepository(),
            localRemover: FridgeLocalRemover(container: stack.container,
                                             removeNotifications: { appDelegate?.removeNotifications(for: $0) })
        )
        vc.onSelect = { [weak vc] fridge in
            SelectedFridgeStore.fridgeID = fridge.fridgeID
            guard let window = vc?.view.window else { return }
            let tabBar = MainTabBarFactory.make(fridge: fridge, stack: stack)
            UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: {
                UIView.setAnimationsEnabled(false)
                window.rootViewController = tabBar
                UIView.setAnimationsEnabled(true)
            }, completion: nil)
        }
        return vc
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
                    self.view.window?.rootViewController = self.makeFridgeSelectionVC()
                    UIView.setAnimationsEnabled(true)
                    printInfo("第三段動畫做完了")
                }, completion: nil)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {}
}
