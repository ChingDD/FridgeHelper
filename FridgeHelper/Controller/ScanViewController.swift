//
//  ScanViewController.swift
//  FridgeHelper
//
//  掃描頁骨架：版面依設計稿，掃描辨識功能尚未實作
//

import UIKit

final class ScanViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        title = "掃描"
        navigationController?.navigationBar.prefersLargeTitles = true

        let receiptCard = makeActionCard(title: "掃描收據", symbol: "doc.text.viewfinder")
        let qrCard = makeActionCard(title: "掃描 QR Code", symbol: "qrcode.viewfinder")
        let cardRow = UIStackView(arrangedSubviews: [receiptCard, qrCard])
        cardRow.axis = .horizontal
        cardRow.spacing = Theme.spacing
        cardRow.distribution = .fillEqually

        let supportChip = UILabel()
        supportChip.text = "  ✓ 支援台灣電子發票 QR CODE  "
        supportChip.font = Theme.font(12, .bold)
        supportChip.textColor = Theme.primaryDeep
        supportChip.backgroundColor = Theme.primary.withAlphaComponent(0.12)
        supportChip.layer.cornerRadius = 14
        supportChip.clipsToBounds = true
        supportChip.textAlignment = .center
        supportChip.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let previewCard = CardView(background: Theme.surface)
        let previewIcon = UIImageView(image: UIImage(systemName: "camera.viewfinder"))
        previewIcon.tintColor = Theme.textSecondary
        previewIcon.contentMode = .scaleAspectFit
        previewIcon.translatesAutoresizingMaskIntoConstraints = false
        previewCard.contentView.addSubview(previewIcon)
        NSLayoutConstraint.activate([
            previewIcon.centerXAnchor.constraint(equalTo: previewCard.contentView.centerXAnchor),
            previewIcon.centerYAnchor.constraint(equalTo: previewCard.contentView.centerYAnchor),
            previewIcon.widthAnchor.constraint(equalToConstant: 56),
            previewIcon.heightAnchor.constraint(equalToConstant: 56),
            previewCard.heightAnchor.constraint(equalToConstant: 220),
        ])

        let comingSoonLabel = UILabel()
        comingSoonLabel.text = "即將推出"
        comingSoonLabel.font = Theme.font(22, .bold)
        comingSoonLabel.textColor = Theme.textPrimary
        comingSoonLabel.textAlignment = .center

        let descriptionLabel = UILabel()
        descriptionLabel.text = "掃描收據或電子發票，自動辨識並加入食材"
        descriptionLabel.font = Theme.font(14)
        descriptionLabel.textColor = Theme.textSecondary
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [cardRow, supportChip, previewCard, comingSoonLabel, descriptionLabel])
        stack.axis = .vertical
        stack.spacing = Theme.spacing
        stack.setCustomSpacing(24, after: previewCard)
        stack.setCustomSpacing(8, after: comingSoonLabel)
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.spacing),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.spacing),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.spacing),
        ])
    }

    private func makeActionCard(title: String, symbol: String) -> UIView {
        let card = CardView(background: Theme.surface)

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = Theme.primary.withAlphaComponent(0.5)
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = title
        label.font = Theme.font(15, .bold)
        label.textColor = Theme.textSecondary
        label.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.heightAnchor.constraint(equalToConstant: 40),
            stack.centerXAnchor.constraint(equalTo: card.contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.contentView.centerYAnchor),
            card.heightAnchor.constraint(equalToConstant: 120),
        ])
        return card
    }
}
