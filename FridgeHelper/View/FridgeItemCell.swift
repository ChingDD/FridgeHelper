//
//  FridgeItemCell.swift
//  FridgeHelper
//

import UIKit

final class FridgeItemCell: UICollectionViewCell {
    static let reuseID = "FridgeItemCell"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    private let card = CardView()
    private let thumbnail = UIImageView()
    private let nameLabel = UILabel()
    private let badge = StatusBadge()
    private let expiryLabel = UILabel()
    private let fromChip = PaddedLabel()
    private let stepper = QuantityStepper()

    var onQuantityChange: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        thumbnail.contentMode = .scaleAspectFill
        thumbnail.clipsToBounds = true
        thumbnail.layer.cornerRadius = 16
        thumbnail.backgroundColor = Theme.surface
        thumbnail.tintColor = Theme.textSecondary

        nameLabel.font = Theme.font(17, .bold)
        nameLabel.textColor = Theme.textPrimary

        expiryLabel.font = Theme.font(13)
        expiryLabel.textColor = Theme.textSecondary

        fromChip.font = Theme.font(11, .medium)
        fromChip.textColor = Theme.textSecondary
        fromChip.backgroundColor = Theme.surface
        fromChip.clipsToBounds = true
        fromChip.layer.cornerRadius = 9

        stepper.minimumValue = 0
        stepper.onChange = { [weak self] value in self?.onQuantityChange?(value) }

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, badge])
        nameRow.spacing = 8
        nameRow.alignment = .center

        let infoRow = UIStackView(arrangedSubviews: [expiryLabel, fromChip, UIView()])
        infoRow.spacing = 8
        infoRow.alignment = .center

        let stepperRow = UIStackView(arrangedSubviews: [stepper, UIView()])

        let rightColumn = UIStackView(arrangedSubviews: [nameRow, infoRow, stepperRow])
        rightColumn.axis = .vertical
        rightColumn.spacing = 8

        let content = UIStackView(arrangedSubviews: [thumbnail, rightColumn])
        content.spacing = 12
        content.alignment = .top
        content.translatesAutoresizingMaskIntoConstraints = false

        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        card.contentView.addSubview(content)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
            thumbnail.widthAnchor.constraint(equalToConstant: 64),
            thumbnail.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        onQuantityChange = nil
    }

    func configure(with item: Item) {
        nameLabel.text = item.name
        expiryLabel.text = "\(Self.dateFormatter.string(from: item.expiryDate)) 到期"

        let status = ItemStatus(expiryDate: item.expiryDate)
        badge.status = status
        card.edgeColor = status.color

        if let image = item.image.flatMap(UIImage.init) {
            thumbnail.image = image
            thumbnail.contentMode = .scaleAspectFill
        } else {
            thumbnail.image = UIImage(systemName: "fork.knife")
            thumbnail.contentMode = .center
        }

        if let updatedBy = item.updatedByName {
            fromChip.text = "來自 \(updatedBy)"
            fromChip.isHidden = false
        } else {
            fromChip.isHidden = true
        }

        stepper.value = item.number
        stepper.unit = item.unit
    }
}

private final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
