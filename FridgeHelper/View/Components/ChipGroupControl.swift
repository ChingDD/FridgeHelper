//
//  ChipGroupControl.swift
//  FridgeHelper
//

import UIKit

/// 單選 chips（例如單位 pcs/g/kg/ml/oz）
final class ChipGroupControl: UIControl {
    private let stack = UIStackView()
    private var buttons: [UIButton] = []

    let options: [String]
    var onSelect: ((String) -> Void)?

    var selectedOption: String {
        didSet { updateAppearance() }
    }

    init(options: [String], selected: String) {
        self.options = options
        self.selectedOption = selected
        super.init(frame: .zero)

        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])

        for (index, option) in options.enumerated() {
            var config = UIButton.Configuration.filled()
            config.title = option
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            let button = UIButton(configuration: config)
            button.tag = index
            button.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func chipTapped(_ sender: UIButton) {
        selectedOption = options[sender.tag]
        onSelect?(selectedOption)
    }

    private func updateAppearance() {
        for button in buttons {
            let isSelected = options[button.tag] == selectedOption
            button.configuration?.baseBackgroundColor = isSelected ? Theme.primary : Theme.surface
            button.configuration?.baseForegroundColor = isSelected ? .white : Theme.textPrimary
            button.configuration?.attributedTitle = AttributedString(
                options[button.tag],
                attributes: AttributeContainer([.font: Theme.font(14, isSelected ? .bold : .medium)])
            )
        }
    }
}
