//
//  MainTabBarController.swift
//  FridgeHelper
//
//  隱藏系統 tab bar，改用自訂浮動玻璃膠囊列
//

import UIKit

final class MainTabBarController: UITabBarController {
    /// 內容在 safe area 之外需額外預留的底部空間（浮動列高 64 + 上下間距），避免被浮動列遮住
    static let barClearance: CGFloat = 80

    private let floatingBar = FloatingTabBarView(tabs: [
        .init(title: "冰箱", symbol: "refrigerator.fill"),
        .init(title: "掃描", symbol: "doc.viewfinder.fill"),
        .init(title: "成員", symbol: "person.2.fill"),
    ])

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.isHidden = true

        floatingBar.onSelect = { [weak self] index in
            self?.selectedIndex = index
        }
        floatingBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(floatingBar)
        NSLayoutConstraint.activate([
            floatingBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            floatingBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            floatingBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            floatingBar.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    override func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        viewControllers?.forEach {
            $0.additionalSafeAreaInsets.bottom = Self.barClearance
        }
    }

    override var selectedIndex: Int {
        didSet { floatingBar.selectedIndex = selectedIndex }
    }
}
