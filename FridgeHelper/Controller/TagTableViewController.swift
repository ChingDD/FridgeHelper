//
//  TagTableViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/2.
//

import UIKit
import Combine

class TagTableViewController: UITableViewController {
    var tagViewModel: TagViewModel!

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "標籤管理"

        // Temporary guard: allow standalone launch without injection
        if tagViewModel == nil { tagViewModel = TagViewModel() }

        bindViewModel()
    }

    private func bindViewModel() {
        tagViewModel.tableUpdateEvent
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                switch event {
                case .reload:
                    self?.tableView.reloadData()
                case .deleteRow(let index):
                    if self?.tagViewModel.tags.isEmpty == false {
                        self?.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
                    } else {
                        self?.tableView.reloadData()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Target Action

    @IBAction func addTag(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: "標籤", message: "新增標籤", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "標籤名稱(不能為空白)"
            textField.delegate = self
        }

        let okAction = UIAlertAction(title: "確認", style: .default) { [weak self] _ in
            guard let self,
                  let tag = alertController.textFields?.first?.text,
                  !tag.isEmpty else { return }
            self.tagViewModel.addTag(tag)
        }

        let cancelAction = UIAlertAction(title: "取消", style: .destructive)
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tagViewModel.tags.isEmpty ? 1 : tagViewModel.tags.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if !tagViewModel.tags.isEmpty {
            let tagCell = tableView.dequeueReusableCell(withIdentifier: "TagTableViewCell", for: indexPath)
            tagCell.imageView?.image = UIImage(systemName: "tag.circle")
            tagCell.imageView?.tintColor = UIColor(named: "Color3")
            tagCell.textLabel?.text = tagViewModel.tags[indexPath.row]
            return tagCell
        } else {
            let noTagCell = tableView.dequeueReusableCell(withIdentifier: "NoTagTableViewCell", for: indexPath)
            noTagCell.textLabel?.text = "尚未建立標籤"
            return noTagCell
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tagViewModel.removeTag(at: indexPath.row)
        }
    }
}

extension TagTableViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return !string.contains(" ")
    }
}
