//
//  ExpiryAlertsViewController.swift
//  FridgeHelper
//
//  到期警示頁（sheet 呈現，取代舊 ExpiredTableViewController）
//

import UIKit
import Combine

final class ExpiryAlertsViewController: UIViewController {

    private let viewModel: MainViewModel
    private var cancellables = Set<AnyCancellable>()

    private var expired: [Item] = []
    private var expiring: [Item] = []

    private let heroLabel = UILabel()
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tableView
    }()

    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        let heroCard = CardView(background: Theme.primary)
        heroLabel.font = Theme.font(28, .bold)
        heroLabel.textColor = .white
        heroLabel.numberOfLines = 0

        let heroSubtitle = UILabel()
        heroSubtitle.text = "保持廚房新鮮、零浪費"
        heroSubtitle.font = Theme.font(15)
        heroSubtitle.textColor = UIColor.white.withAlphaComponent(0.85)

        let heroStack = UIStackView(arrangedSubviews: [heroLabel, heroSubtitle])
        heroStack.axis = .vertical
        heroStack.spacing = 6
        heroStack.translatesAutoresizingMaskIntoConstraints = false
        heroCard.contentView.addSubview(heroStack)
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(heroCard)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            heroStack.topAnchor.constraint(equalTo: heroCard.contentView.topAnchor, constant: 24),
            heroStack.bottomAnchor.constraint(equalTo: heroCard.contentView.bottomAnchor, constant: -24),
            heroStack.leadingAnchor.constraint(equalTo: heroCard.contentView.leadingAnchor, constant: 24),
            heroStack.trailingAnchor.constraint(equalTo: heroCard.contentView.trailingAnchor, constant: -24),

            heroCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            heroCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            heroCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        viewModel.$expiredItems
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                guard let self else { return }
                self.expired = items.filter { $0.expiryDate.timeIntervalSinceNow < 0 }
                self.expiring = items.filter { $0.expiryDate.timeIntervalSinceNow >= 0 }
                self.heroLabel.text = "\(items.count) 項需要注意"
                self.tableView.reloadData()
            }
            .store(in: &cancellables)
    }
}

// MARK: - UITableViewDataSource

extension ExpiryAlertsViewController: UITableViewDataSource {
    private func items(in section: Int) -> [Item] {
        section == 0 ? expired : expiring
    }

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let items = items(in: section)
        let title = section == 0 ? "已過期" : "即將到期"
        return items.isEmpty ? nil : "\(title)（\(items.count) 項）"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items(in: section).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = items(in: indexPath.section)[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = item.name
        content.textProperties.font = Theme.font(16, .bold)
        content.textProperties.color = Theme.textPrimary

        let days = Int(ceil(abs(item.expiryDate.timeIntervalSinceNow) / 86400))
        if indexPath.section == 0 {
            content.secondaryText = "\(item.storeLocation) • 已過期 \(days) 天"
            content.secondaryTextProperties.color = Theme.danger
        } else {
            content.secondaryText = "\(item.storeLocation) • 還有 \(max(1, days)) 天到期"
            content.secondaryTextProperties.color = Theme.warningDeep
        }
        content.secondaryTextProperties.font = Theme.font(13, .medium)

        if let image = item.image.flatMap(UIImage.init) {
            content.image = image
            content.imageProperties.maximumSize = CGSize(width: 48, height: 48)
            content.imageProperties.cornerRadius = 12
        } else {
            content.image = UIImage(systemName: "fork.knife.circle.fill")
            content.imageProperties.tintColor = Theme.textSecondary
        }

        cell.contentConfiguration = content
        cell.backgroundColor = Theme.surface
        cell.selectionStyle = .none
        return cell
    }
}
