//
//  ExpiredTableViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/15.
//

import UIKit
import Combine

class ExpiredTableViewController: UITableViewController {

    var viewModel: MainViewModel!

    var desiredWidth: CGFloat!
    var desiredHeight: CGFloat!
    var offSetX: CGFloat!
    var offSetY: CGFloat!
    var isViewDissapear: Bool = true

    private var expiredItems: [Item] = []
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        printInfo("viewDidLoad")
        title = "即將過期的食品！"

        // Temporary guard: allow standalone launch without injection
        if viewModel == nil, let stack = (UIApplication.shared.delegate as? AppDelegate)?.sharedStack {
            let repo = SwiftDataItemRepository(container: stack.container)
            viewModel = MainViewModel(tagViewModel: TagViewModel(repository: repo), local: repo)
        }

        bindViewModel()
    }

    private func bindViewModel() {
        viewModel.$expiredItems
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.expiredItems = items
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    @IBAction func backToMain(_ sender: Any) {
        dismiss(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        printInfo("viewWillAppear")

        if isViewDissapear {
            desiredWidth = view.frame.size.width * 0.8
            desiredHeight = view.frame.size.height * 0.75
            offSetX = view.frame.size.width - desiredWidth
            offSetY = view.frame.size.height - desiredHeight

            view.frame.size.width = desiredWidth
            view.frame.size.height = desiredHeight
            view.frame.origin.x = offSetX / 2
            view.frame.origin.y = offSetY / 2
            view.layer.cornerRadius = 20
            view.clipsToBounds = true
            isViewDissapear = false
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        isViewDissapear = true
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return expiredItems.isEmpty ? 1 : expiredItems.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        printInfo("cellForRow")

        guard !expiredItems.isEmpty else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NoExpiredTableViewCell", for: indexPath)
            return cell
        }

        let item = expiredItems[indexPath.section]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExpiredTableViewCell", for: indexPath) as! ExpiredTableViewCell

        cell.amountsLabel.text = "\(item.number)"

        if item.expiryDate.timeIntervalSinceNow > -(60 * 60 * 24) {
            cell.expiredDateLabel.text = dateController.shared.setDateFormate(item.expiryDate)
            cell.expiredDateLabel.textColor = UIColor(named: "Color6")
        } else {
            let expiredDay = Int((-item.expiryDate.timeIntervalSinceNow) / (60 * 60 * 24))
            cell.expiredDateLabel.text = "物品已經過期\(expiredDay)天"
            cell.expiredDateLabel.textColor = UIColor.red
        }

        if item.memo != nil {
            cell.memoLabel.isHidden = false
            cell.memoTitleLabel.isHidden = false
            cell.memoLabel.text = item.memo
        } else {
            cell.memoLabel.isHidden = true
            cell.memoTitleLabel.isHidden = true
        }

        cell.nameLabel.text = item.name

        if let imageData = item.image, let image = UIImage(data: imageData) {
            cell.itemImageView.image = image
        } else {
            cell.itemImageView.image = nil
        }
        cell.itemImageView.contentMode = .scaleAspectFill

        for aView in cell.contentView.subviews {
            if let label = aView as? UILabel {
                label.sizeToFit()
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return expiredItems.isEmpty ? tableView.frame.height : UITableView.automaticDimension
    }
}
