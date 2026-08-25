//
//  FridgeViewController.swift
//  FridgeHelper
//
//  冰箱儀表板：到期橫幅、儲存位置／標籤篩選（文字框＋UIMenu）、卡片清單、FAB
//

import UIKit
import Combine

final class FridgeViewController: UIViewController {

    var viewModel: MainViewModel!

    private var cancellables = Set<AnyCancellable>()
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!

    // MARK: - UI

    private let bannerCard = CardView(background: Theme.warning.withAlphaComponent(0.18))
    private let bannerLabel = UILabel()
    private let locationField = MenuFieldControl(value: "全部位置")
    private let tagField = MenuFieldControl(value: "全部標籤")
    private let sortButton = UIButton()
    private let fab = FloatingActionButton()
    private let emptyLabel = UILabel()
    private let savedItemNumLabel = UILabel()

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "搜尋食材"
        return searchController
    }()

    private lazy var collectionView: UICollectionView = {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        config.showsSeparators = false
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let item = self.item(at: indexPath) else { return nil }
            let delete = UIContextualAction(style: .destructive, title: "刪除") { _, _, done in
                self.viewModel.removeItem(item)
                done(true)
            }
            return UISwipeActionsConfiguration(actions: [delete])
        }
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        return collectionView
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        setupLayout()
        setupDataSource()
        setupBindings()

        viewModel.notificationDelegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.refreshExpiredItems()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup

    /// 品牌列：冰箱 icon（淺 teal 底）＋ teal 標題＋放大鏡，取代 navigation bar
    private func makeBrandRow() -> UIView {
        let iconContainer = UIView()
        iconContainer.backgroundColor = Theme.primary.withAlphaComponent(0.12)
        iconContainer.layer.cornerRadius = 10

        let icon = UIImageView(image: UIImage(systemName: "refrigerator", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)))
        icon.tintColor = Theme.primaryDeep
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(icon)

        let titleLabel = UILabel()
        titleLabel.text = "FridgeHelper"
        titleLabel.font = Theme.font(21, .bold)
        titleLabel.textColor = Theme.primaryDeep

        let searchButton = UIButton(type: .system)
        searchButton.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
        searchButton.tintColor = Theme.textPrimary
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [iconContainer, titleLabel, UIView(), searchButton])
        row.spacing = 10
        row.alignment = .center

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 36),
            iconContainer.heightAnchor.constraint(equalToConstant: 36),
            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 40),
            searchButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        return row
    }

    private func setupLayout() {
        // 到期橫幅
        let bannerIcon = UIImageView(image: UIImage(systemName: "exclamationmark.circle.fill"))
        bannerIcon.tintColor = Theme.warningDeep
        bannerIcon.setContentHuggingPriority(.required, for: .horizontal)

        bannerLabel.font = Theme.font(15, .bold)
        bannerLabel.textColor = Theme.warningDeep

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = Theme.warningDeep
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let bannerStack = UIStackView(arrangedSubviews: [bannerIcon, bannerLabel, UIView(), chevron])
        bannerStack.spacing = 10
        bannerStack.alignment = .center
        bannerStack.translatesAutoresizingMaskIntoConstraints = false
        bannerCard.contentView.addSubview(bannerStack)
        bannerCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(bannerTapped)))

        // 篩選列（位置＋標籤＋排序）
        var sortConfig = UIButton.Configuration.filled()
        sortConfig.baseBackgroundColor = Theme.surface
        sortConfig.baseForegroundColor = Theme.primaryDeep
        sortConfig.image = UIImage(systemName: "arrow.up.arrow.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        sortConfig.background.cornerRadius = Theme.cornerButton
        sortButton.configuration = sortConfig
        sortButton.showsMenuAsPrimaryAction = true
        sortButton.menu = buildSortMenu()

        let filterRow = UIStackView(arrangedSubviews: [locationField, tagField, sortButton])
        filterRow.spacing = 10
        
        savedItemNumLabel.font = Theme.font(13, .semibold)
        savedItemNumLabel.textColor = Theme.textSecondary
        savedItemNumLabel.textAlignment = .right

        let headerStack = UIStackView(arrangedSubviews: [makeBrandRow(), bannerCard, filterRow, savedItemNumLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 12
        headerStack.setCustomSpacing(8, after: filterRow)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        view.addSubview(fab)
        fab.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        emptyLabel.text = "冰箱是空的，點右下角＋新增食材"
        emptyLabel.font = Theme.font(15)
        emptyLabel.textColor = Theme.textSecondary
        emptyLabel.textAlignment = .center

        NSLayoutConstraint.activate([
            bannerStack.topAnchor.constraint(equalTo: bannerCard.contentView.topAnchor, constant: 14),
            bannerStack.bottomAnchor.constraint(equalTo: bannerCard.contentView.bottomAnchor, constant: -14),
            bannerStack.leadingAnchor.constraint(equalTo: bannerCard.contentView.leadingAnchor, constant: 16),
            bannerStack.trailingAnchor.constraint(equalTo: bannerCard.contentView.trailingAnchor, constant: -16),

            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            fab.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            fab.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            locationField.widthAnchor.constraint(equalTo: tagField.widthAnchor),
            sortButton.widthAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func setupDataSource() {
        collectionView.register(FridgeItemCell.self, forCellWithReuseIdentifier: FridgeItemCell.reuseID)
        dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { [weak self] collectionView, indexPath, _ in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FridgeItemCell.reuseID, for: indexPath) as! FridgeItemCell
            if let self, let item = self.item(at: indexPath) {
                cell.configure(with: item)
                cell.onQuantityChange = { [weak self] value in
                    self?.viewModel.updateQuantity(of: item, to: value)
                }
            }
            return cell
        }
    }

    private func setupBindings() {
        viewModel.$displayedItems
            .receive(on: RunLoop.main)
            .sink { [weak self] items in self?.applySnapshot(for: items) }
            .store(in: &cancellables)

        viewModel.$savedItemCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                guard let self else { return }
                self.savedItemNumLabel.text = "食材 \(count) / \(self.viewModel.itemCapacity)"
            }
            .store(in: &cancellables)

        viewModel.$expiredCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.bannerCard.isHidden = count == 0
                self?.bannerLabel.text = "\(count) 項食材即將到期"
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(viewModel.locations.$values, viewModel.locations.$selected)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, selected in
                guard let self else { return }
                self.locationField.setValue(selected ?? "全部位置")
                self.locationField.menu = self.buildLocationMenu()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(viewModel.tags.$values, viewModel.tags.$selected)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, selected in
                guard let self else { return }
                self.tagField.setValue(selected ?? "全部標籤")
                self.tagField.menu = self.buildTagMenu()
            }
            .store(in: &cancellables)
    }

    // MARK: - Snapshot

    private func item(at indexPath: IndexPath) -> Item? {
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return viewModel.displayedItems.first { $0.timeStamp == id }
    }

    private func applySnapshot(for items: [Item]) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        let ids = items.map { $0.timeStamp ?? UUID().uuidString }
        snapshot.appendItems(ids)
        snapshot.reconfigureItems(ids)
        dataSource.apply(snapshot, animatingDifferences: true)
        collectionView.backgroundView = items.isEmpty ? emptyLabel : nil
    }

    // MARK: - Menus

    private func buildSortMenu() -> UIMenu {
        let actions = SortMethod.allCases.map { method in
            UIAction(title: method.rawValue, state: viewModel.sortOption == method ? .on : .off) { [weak self] _ in
                self?.viewModel.sortOption = method
                self?.sortButton.menu = self?.buildSortMenu()
            }
        }
        return UIMenu(options: .singleSelection, children: actions)
    }

    private func buildLocationMenu() -> UIMenu {
        var actions = [UIAction(title: "全部位置", state: viewModel.locations.selected == nil ? .on : .off) { [weak self] _ in
            self?.viewModel.locations.selected = nil
        }]
        actions += viewModel.locations.values.map { location in
            UIAction(title: location, state: viewModel.locations.selected == location ? .on : .off) { [weak self] _ in
                self?.viewModel.locations.selected = location
            }
        }
        let manage = UIAction(title: "管理儲存位置…", image: UIImage(systemName: "slider.horizontal.3")) { [weak self] _ in
            guard let self else { return }
            let manageVC = ManageListViewController(listTitle: "儲存位置", viewModel: self.viewModel.locations)
            self.navigationController?.pushViewController(manageVC, animated: true)
        }
        return UIMenu(children: [
            UIMenu(options: .displayInline, children: actions),
            manage,
        ])
    }

    private func buildTagMenu() -> UIMenu {
        var actions = [UIAction(title: "全部標籤", state: viewModel.tags.selected == nil ? .on : .off) { [weak self] _ in
            self?.viewModel.tags.selected = nil
        }]
        actions += viewModel.tags.values.map { tag in
            UIAction(title: tag, state: viewModel.tags.selected == tag ? .on : .off) { [weak self] _ in
                self?.viewModel.tags.selected = tag
            }
        }
        let manage = UIAction(title: "管理標籤…", image: UIImage(systemName: "tag")) { [weak self] _ in
            guard let self else { return }
            let manageVC = ManageListViewController(listTitle: "標籤", viewModel: self.viewModel.tags)
            self.navigationController?.pushViewController(manageVC, animated: true)
        }
        return UIMenu(children: [
            UIMenu(options: .displayInline, children: actions),
            manage,
        ])
    }

    // MARK: - Actions

    @objc private func addTapped() {
        // 先擋在這裡，避免使用者填完整張表單才發現不能存
        if let rejection = viewModel.addItemRejection {
            presentCapacityAlert(rejection)
            return
        }
        presentForm(editing: nil)
    }

    /// 階段四導入 StoreKit 後，ownerCanUpgrade 可在這裡加上「升級家庭版」動作
    private func presentCapacityAlert(_ rejection: ItemCapacityRejection) {
        let alert = UIAlertController(title: rejection.alertTitle, message: rejection.alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }

    @objc private func searchTapped() {
        present(searchController, animated: true)
    }

    @objc private func bannerTapped() {
        let alertsVC = ExpiryAlertsViewController(viewModel: viewModel)
        if let sheet = alertsVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(alertsVC, animated: true)
    }

    private func presentForm(editing item: Item?) {
        let editViewModel = EditViewModel(
            existingItem: item,
            availableTags: viewModel.tags.values,
            defaultLocation: viewModel.locations.values.first ?? "冷藏"
        )
        let formVC = ItemFormViewController(editViewModel: editViewModel, locations: viewModel.locations)
        formVC.onSave = { [weak self] newItem in
            guard let self else { return nil }
            // 更新永遠放行，只有新增要經過容量閘門
            if let item {
                self.viewModel.updateItem(item, with: newItem)
                return nil
            }
            return self.viewModel.addItem(newItem)
        }
        let nav = UINavigationController(rootViewController: formVC)
        present(nav, animated: true)
    }
}

// MARK: - UICollectionViewDelegate

extension FridgeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = item(at: indexPath) else { return }
        presentForm(editing: item)
    }
}

// MARK: - UISearchResultsUpdating / UISearchControllerDelegate

extension FridgeViewController: UISearchResultsUpdating, UISearchControllerDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchKeyword = searchController.searchBar.text ?? ""
    }

    func didDismissSearchController(_ searchController: UISearchController) {
        viewModel.searchKeyword = ""
    }
}

// MARK: - NotificationManagerDelegate

extension FridgeViewController: NotificationManagerDelegate {
    func rescheduleNotification(for item: Item) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.scheduleNotification(for: item)
    }

    func removeNotifications(for item: Item) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.removeNotifications(for: item)
    }
}
