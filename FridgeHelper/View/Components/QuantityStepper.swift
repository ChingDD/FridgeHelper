//
//  QuantityStepper.swift
//  FridgeHelper
//

import UIKit

/// −／數值＋單位／＋ 的三段式膠囊控制項
final class QuantityStepper: UIControl {
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()

    var minimumValue = 0
    var onChange: ((Int) -> Void)?

    var value: Int = 0 {
        didSet { valueLabel.text = "\(value)" }
    }

    var unit: String = "" {
        didSet { unitLabel.text = unit }
    }

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.surface
        layer.cornerRadius = Theme.cornerButton
        clipsToBounds = true

        let minusButton = makeButton(symbol: "minus", action: #selector(decrease))
        let plusButton = makeButton(symbol: "plus", action: #selector(increase))

        valueLabel.font = Theme.font(17, .bold)
        valueLabel.textColor = Theme.textPrimary
        valueLabel.textAlignment = .center
        unitLabel.font = Theme.font(12, .medium)
        unitLabel.textColor = Theme.textSecondary
        unitLabel.textAlignment = .center

        let centerStack = UIStackView(arrangedSubviews: [valueLabel, unitLabel])
        centerStack.axis = .vertical

        let stack = UIStackView(arrangedSubviews: [minusButton, centerStack, plusButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            centerStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeButton(symbol: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold))
        config.baseForegroundColor = Theme.textPrimary
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func decrease() {
        guard value > minimumValue else { return }
        value -= 1
        onChange?(value)
    }

    @objc private func increase() {
        value += 1
        onChange?(value)
    }
}
