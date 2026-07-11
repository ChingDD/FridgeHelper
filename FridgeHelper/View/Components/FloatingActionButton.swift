//
//  FloatingActionButton.swift
//  FridgeHelper
//

import UIKit

final class FloatingActionButton: UIButton {

    init(symbol: String = "plus") {
        super.init(frame: .zero)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = Theme.primary
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold))
        config.background.cornerRadius = 18
        configuration = config

        layer.shadowColor = Theme.primaryDeep.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 56),
            heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
