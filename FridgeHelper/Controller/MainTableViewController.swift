//
//  MainTableViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import UIKit
import UserNotifications
import Combine
import CloudKit

class MainTableViewController: UITableViewController {

    @IBOutlet weak var storeConditionSegmentControl: UISegmentedControl!
    @IBOutlet weak var tagFilterBtn: UIButton!
    @IBOutlet weak var sortItemBtn: UIButton!
    @IBOutlet weak var tableHeaderView: UIView!
    @IBOutlet weak var expiredAmounts: UILabel!

    // Injected by LunchingViewController
    var viewModel: MainViewModel!
    var tagViewModel: TagViewModel!
    /// 僅 Owner 裝置注入；nil 表示 Participant，不顯示分享按鈕
    var shareManager: SharingRepositoryProtocol?

    var isCellSelected = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - ViewController Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Temporary guard: allow standalone launch without injection
        if let stack = (UIApplication.shared.delegate as? AppDelegate)?.sharedStack {
            if viewModel == nil {
                let repo = SwiftDataItemRepository(container: stack.container)
                let tempTag = TagViewModel(repository: repo)
                tagViewModel = tempTag
                viewModel = MainViewModel(tagViewModel: tempTag, local: repo)
            }
            if tagViewModel == nil {
                tagViewModel = TagViewModel(repository: SwiftDataItemRepository(container: stack.container))
            }
        }

        viewModel.notificationDelegate = self

        // Search controller
        let searchController = UISearchController()
        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self

        // SegmentControl UI
        storeConditionSegmentControl.setTitleTextAttributes(
            [NSAttributedString.Key.foregroundColor: UIColor(named: "Color6")!], for: .selected)
        storeConditionSegmentControl.setTitleTextAttributes(
            [NSAttributedString.Key.foregroundColor: UIColor(named: "Color7")!], for: .normal)

        // Sort button menu
        sortItemBtn.menu = buildSortMenu()
        sortItemBtn.showsMenuAsPrimaryAction = true

        // Tag filter button
        tagFilterBtn.showsMenuAsPrimaryAction = true

        title = "FridgeHelper"

        // 分享按鈕：僅 Owner 裝置顯示
        if shareManager != nil {
            let shareBtn = UIBarButtonItem(
                image: UIImage(systemName: "person.crop.circle.badge.plus"),
                style: .plain,
                target: self,
                action: #selector(shareTapped)
            )
            navigationItem.leftBarButtonItem = shareBtn
        }

        bindViewModel()

        // Initial table load (pipeline fires async, so reload explicitly)
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload tag filter menu in case tags changed
        tagFilterBtn.menu = buildTagMenu()
        // Refresh expired items in case time has passed
        viewModel.refreshExpiredItems()
        isCellSelected = false
    }

    // MARK: - Combine Bindings

    private func bindViewModel() {
        // Table update events (reload / delete / reloadRow)
        viewModel.tableUpdateEvent
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                switch event {
                case .reload:
                    self?.tableView.reloadData()
                case .deleteSection(let i):
                    if self?.viewModel.displayedItems.isEmpty == true {
                        self?.tableView.reloadData()
                    } else {
                        self?.tableView.deleteSections(IndexSet(integer: i), with: .fade)
                    }
                case .reloadSection(let i):
                    self?.tableView.reloadRows(at: [IndexPath(row: 0, section: i)], with: .automatic)
                }
            }
            .store(in: &cancellables)

        // Expired badge
        viewModel.$expiredCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.expiredAmounts.isHidden = count == 0
                self?.expiredAmounts.text = "\(count)"
            }
            .store(in: &cancellables)

        // Tag list changes → rebuild tag menu
        tagViewModel.$tags
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.tagFilterBtn.menu = self?.buildTagMenu()
            }
            .store(in: &cancellables)

        // Selected tag changes → update tag menu checkmark UI
        tagViewModel.$selectedTag
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.tagFilterBtn.menu = self?.buildTagMenu()
            }
            .store(in: &cancellables)
    }

    // MARK: - Menu Builders

    private func buildTagMenu() -> UIMenu {
        let tags = tagViewModel.tags
        guard !tags.isEmpty else {
            let noTagBtn = UIAction(title: "尚未建立標籤") { _ in }
            return UIMenu(title: "標籤篩選器", options: .displayInline, children: [noTagBtn])
        }

        let cancelAction = UIAction(
            title: "取消標籤選擇",
            state: tagViewModel.selectedTag == nil ? .on : .off
        ) { [weak self] _ in
            self?.tagViewModel.selectedTag = nil
        }

        let tagActions = tags.map { tag -> UIAction in
            UIAction(
                title: tag,
                state: self.tagViewModel.selectedTag == tag ? .on : .off
            ) { [weak self] _ in
                self?.tagViewModel.selectedTag = tag
            }
        }

        return UIMenu(title: "標籤篩選器", options: .singleSelection, children: [cancelAction] + tagActions)
    }

    private func buildSortMenu() -> UIMenu {
        let cancelBtn = UIAction(title: "取消", state: .on) { [weak self] _ in
            self?.viewModel.sortOption = .取消
        }
        let sortBtn1 = UIAction(title: SortMethod.時間排序遠到近.rawValue) { [weak self] _ in
            self?.viewModel.sortOption = .時間排序遠到近
        }
        let sortBtn2 = UIAction(title: SortMethod.時間排序近到遠.rawValue) { [weak self] _ in
            self?.viewModel.sortOption = .時間排序近到遠
        }
        let sortBtn3 = UIAction(title: SortMethod.剩餘數量多到少.rawValue) { [weak self] _ in
            self?.viewModel.sortOption = .剩餘數量多到少
        }
        let sortBtn4 = UIAction(title: SortMethod.剩餘數量少到多.rawValue) { [weak self] _ in
            self?.viewModel.sortOption = .剩餘數量少到多
        }
        return UIMenu(title: "分類", options: .singleSelection, children: [cancelBtn, sortBtn1, sortBtn2, sortBtn3, sortBtn4])
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if isCellSelected {
            guard let index = tableView.indexPathForSelectedRow?.section,
                  let controller = segue.destination as? EditViewController else {
                printInfo("Can't Find Controller")
                return
            }
            let selectedItem = viewModel.displayedItems[index]
            controller.editViewModel = EditViewModel(existingItem: selectedItem, availableTags: tagViewModel.tags)
        } else {
            // New item
            if let controller = segue.destination as? EditViewController {
                controller.editViewModel = EditViewModel(availableTags: tagViewModel.tags)
            }
        }

        if let tagVC = segue.destination as? TagTableViewController {
            tagVC.tagViewModel = tagViewModel
        }

        if let expiredVC = segue.destination as? ExpiredTableViewController {
            expiredVC.viewModel = viewModel
        }
    }

    // MARK: - Target Actions

    @IBAction func unwindToMain(_ unwindSegue: UIStoryboardSegue) {
        guard let controller = unwindSegue.source as? EditViewController,
              let item = controller.builtItem else { return }

        if isCellSelected {
            printInfo("進入修改區段")
            let index = tableView.indexPathForSelectedRow!.section
            viewModel.updateItem(at: index, with: item)
        } else {
            printInfo("進入新增區段")
            viewModel.addItem(item)
        }
    }

    @IBAction func chooseStoreCondition(_ sender: UISegmentedControl) {
        viewModel.segmentIndex = sender.selectedSegmentIndex
    }

    @IBAction func changeAmount(_ sender: UIButton) {
        let point = sender.convert(CGPoint.zero, to: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point),
              !viewModel.displayedItems.isEmpty else { return }

        var showedItem = viewModel.displayedItems[indexPath.section]
        var number = showedItem.number
        switch sender.tag {
        case 0: number += 1
        case 1: number = max(0, number - 1)
        default: break
        }

        let cell = tableView.cellForRow(at: indexPath) as! ItemTableViewCell
        cell.numberLabel.text = "\(number)"

        showedItem.number = number
        viewModel.updateItem(at: indexPath.section, with: showedItem)
    }

    // MARK: - Table View Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.displayedItems.isEmpty ? 1 : viewModel.displayedItems.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !viewModel.displayedItems.isEmpty else {
            return tableView.dequeueReusableCell(withIdentifier: "NoItemTableViewCell", for: indexPath)
        }

        let itemcell = tableView.dequeueReusableCell(withIdentifier: "ItemTableViewCell", for: indexPath) as! ItemTableViewCell
        let item = viewModel.displayedItems[indexPath.section]

        itemcell.dateTextField.text = dateController.shared.setDateFormate(item.expiryDate)
        itemcell.dateTextField.sizeToFit()
        itemcell.itemNameLabel.text = item.name
        itemcell.itemNameLabel.sizeToFit()
        itemcell.numberLabel.text = "\(item.number)"

        if let memo = item.memo {
            itemcell.memoLabel.text = memo
            itemcell.memoLabel.sizeToFit()
            itemcell.memoLabel.isHidden = false
            itemcell.memoTitleLabel.isHidden = false
        } else {
            itemcell.memoLabel.isHidden = true
            itemcell.memoTitleLabel.isHidden = true
        }

        if let imageData = item.image {
            itemcell.itemImageView.image = UIImage(data: imageData)
        } else {
            itemcell.itemImageView.image = nil
        }
        itemcell.itemImageView.contentMode = .scaleAspectFill

        return itemcell
    }

    // MARK: - Table View Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {}

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        isCellSelected = true
        return indexPath
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let buttonDelete = UIContextualAction(style: .normal, title: "刪除") { [weak self] _, _, _ in
            self?.viewModel.removeItem(at: indexPath.section)
        }
        buttonDelete.backgroundColor = .red
        let config = UISwipeActionsConfiguration(actions: [buttonDelete])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
}

// MARK: - UISearchResultsUpdating
extension MainTableViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchKeyword = searchController.searchBar.text ?? ""
    }
}

// MARK: - CloudKit Sharing
extension MainTableViewController: UICloudSharingControllerDelegate {

    @objc private func shareTapped() {
        guard let shareManager else { return }

        Future<(CKShare, CKContainer), Error> { promise in
            Task {
                do {
                    promise(.success(try await shareManager.fetchOrCreateShare()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: RunLoop.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                guard case .failure(let error) = completion else { return }
                let alert = UIAlertController(title: "分享失敗", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "確定", style: .default))
                self?.present(alert, animated: true)
            },
            receiveValue: { [weak self] share, container in
                guard let self else { return }
                let sharingController = UICloudSharingController(share: share, container: container)
                sharingController.delegate = self
                sharingController.availablePermissions = [.allowReadWrite, .allowPrivate]
                self.present(sharingController, animated: true)
            }
        )
        .store(in: &cancellables)
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        let alert = UIAlertController(title: "儲存分享失敗", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }

    func itemTitle(for csc: UICloudSharingController) -> String? { "我的冰箱" }
}

// MARK: - NotificationManagerDelegate
extension MainTableViewController: NotificationManagerDelegate {
    func rescheduleNotification(for item: Item) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.scheduleNotification(for: item)
        }
    }

    func removeNotifications(for item: Item) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.removeNotifications(for: item)
        }
    }
}
