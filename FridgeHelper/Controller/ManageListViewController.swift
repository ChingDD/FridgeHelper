//
//  ManageListViewController.swift
//  FridgeHelper
//
//  泛用清單管理頁：儲存位置／標籤的新增與刪除
//

import UIKit
import Combine

final class ManageListViewController: UIViewController {

    private let listTitle: String
    private let viewModel: StringListViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tableView
    }()

    init(listTitle: String, viewModel: StringListViewModel) {
        self.listTitle = listTitle
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        title = "管理\(listTitle)"

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = Theme.primary
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: "plus.circle.fill")
        config.imagePadding = 8
        config.attributedTitle = AttributedString(
            "新增\(listTitle)",
            attributes: AttributeContainer([.font: Theme.font(17, .bold)])
        )
        config.background.cornerRadius = Theme.cornerButton
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        let addButton = UIButton(configuration: config)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addButton)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            addButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.spacing),
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        viewModel.$values
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.tableView.reloadData() }
            .store(in: &cancellables)
    }

    @objc private func addTapped() {
        let alert = UIAlertController(title: "新增\(listTitle)", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = self.listTitle }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "新增", style: .default) { [weak self] _ in
            guard let self,
                  let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !text.isEmpty else { return }
            self.viewModel.add(text)
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension ManageListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.values.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = viewModel.values[indexPath.row]
        content.textProperties.font = Theme.font(16, .semibold)
        content.textProperties.color = Theme.textPrimary
        content.image = UIImage(systemName: listTitle == "標籤" ? "tag.circle.fill" : "tray.circle.fill")
        content.imageProperties.tintColor = Theme.primary
        cell.contentConfiguration = content
        cell.backgroundColor = Theme.surface
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        viewModel.remove(at: indexPath.row)
    }
}
