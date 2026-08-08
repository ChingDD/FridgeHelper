//
//  CardView.swift
//  FridgeHelper
//

import UIKit

/// 設計系統卡片：surface 底色、圓角、環境陰影。
/// 子視圖請加在 `contentView` 上（contentView 會裁切圓角，外層保留陰影）。
final class CardView: UIView {
    let contentView = UIView()

    init(background: UIColor = Theme.surfaceElevated, cornerRadius: CGFloat = Theme.cornerCard) {
        super.init(frame: .zero)
        Theme.applyAmbientShadow(to: self)

        contentView.backgroundColor = background
        contentView.layer.cornerRadius = cornerRadius
        contentView.clipsToBounds = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
