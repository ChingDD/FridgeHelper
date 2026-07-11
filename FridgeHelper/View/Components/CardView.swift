//
//  CardView.swift
//  FridgeHelper
//

import UIKit

/// 設計系統卡片：surface 底色、圓角、環境陰影，可選左側狀態色條。
/// 子視圖請加在 `contentView` 上（contentView 會裁切圓角，外層保留陰影）。
final class CardView: UIView {
    let contentView = UIView()
    private let edgeBar = UIView()

    var edgeColor: UIColor? {
        didSet { edgeBar.backgroundColor = edgeColor ?? .clear }
    }

    init(background: UIColor = Theme.surfaceElevated, cornerRadius: CGFloat = Theme.cornerCard) {
        super.init(frame: .zero)
        Theme.applyAmbientShadow(to: self)

        contentView.backgroundColor = background
        contentView.layer.cornerRadius = cornerRadius
        contentView.clipsToBounds = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        edgeBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(edgeBar)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            edgeBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            edgeBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            edgeBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            edgeBar.widthAnchor.constraint(equalToConstant: 4),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
