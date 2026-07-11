//
//  FloatingTabBarView.swift
//  FridgeHelper
//

import UIKit

final class FloatingTabBarView: UIView {
    struct Tab {
        let title: String
        let symbol: String
    }

    var onSelect: ((Int) -> Void)?

    var selectedIndex: Int = 0 {
        didSet { updateAppearance() }
    }

    private var buttons: [UIButton] = []

    init(tabs: [Tab]) {
        super.init(frame: .zero)
        Theme.applyAmbientShadow(to: self)
        layer.shadowOpacity = 0.12

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blur.layer.cornerRadius = 28
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        for (index, tab) in tabs.enumerated() {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: tab.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
            config.imagePlacement = .top
            config.imagePadding = 4
            config.attributedTitle = AttributedString(
                tab.title,
                attributes: AttributeContainer([.font: Theme.font(11, .bold)])
            )
            config.background.cornerRadius = 20
            let button = UIButton(configuration: config)
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            buttons.append(button)
        }

        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -8),
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tabTapped(_ sender: UIButton) {
        selectedIndex = sender.tag
        onSelect?(sender.tag)
    }

    private func updateAppearance() {
        for button in buttons {
            let isSelected = button.tag == selectedIndex
            button.configuration?.baseForegroundColor = isSelected ? Theme.primaryDeep : Theme.textSecondary
            button.configuration?.baseBackgroundColor = isSelected ? Theme.primary.withAlphaComponent(0.12) : .clear
        }
    }
}
