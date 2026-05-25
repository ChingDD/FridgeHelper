//
//  LunchingViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/18.
//

import UIKit

class LunchingViewController: UIViewController {
    var timer: Timer?

    var launchScreen: UIViewController?
    var dotNumbers = 0

    // Shared ViewModel instances — created once here and injected down the stack

    private var sharedTagViewModel: TagViewModel!
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
        sharedTagViewModel = TagViewModel(repository: localRepo)
        sharedMainViewModel = MainViewModel(tagViewModel: sharedTagViewModel, local: compositeRepo)
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
                    guard let navVC = self.storyboard?.instantiateViewController(identifier: "NavigationController") as? UINavigationController,
                          let mainVC = navVC.viewControllers.first as? MainTableViewController else {
                        // Fallback: transition without injection
                        UIView.setAnimationsEnabled(false)
                        self.view.window?.rootViewController = self.storyboard?.instantiateViewController(identifier: "NavigationController")
                        UIView.setAnimationsEnabled(true)
                        return
                    }
                    mainVC.viewModel = self.sharedMainViewModel
                    mainVC.tagViewModel = self.sharedTagViewModel
                    mainVC.shareManager = ShareManager(zoneMgr: ZoneManager())
                    UIView.setAnimationsEnabled(false)
                    self.view.window?.rootViewController = navVC
                    UIView.setAnimationsEnabled(true)
                    printInfo("第三段動畫做完了")
                }, completion: nil)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {}
}
