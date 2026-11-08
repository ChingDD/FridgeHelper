//
//  FridgeSelectionViewController.swift
//  FridgeHelper
//
//  Created by 姐夫 on 2026/9/26.
//

import UIKit
import Combine

class FridgeSelectionViewController: UIViewController {
    
    var viewModel: FridgeViewModel!
    /// 使用者點選冰箱時通知外層，由外層決定如何進入主畫面
    var onSelect: ((Fridge) -> Void)?
    
    private var collectionView: UICollectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    
    private var dataSource: UICollectionViewDiffableDataSource<Int,Fridge>!

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupDataSource()
        setupUI()
        setupBindings()
    }

    private func setupBindings() {
        viewModel.$fridges
            .receive(on: RunLoop.main)
            .sink { [weak self] fridges in
                self?.applySnapshot(fridges)
            }
            .store(in: &cancellables)
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(0.5))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
        let layout = UICollectionViewCompositionalLayout(section: NSCollectionLayoutSection(group: group))
        collectionView.setCollectionViewLayout(layout, animated: false)
    }
    
    private func setupDataSource() {
        let regist = UICollectionView.CellRegistration<UICollectionViewListCell,Fridge> {cell,indexPath,fridge in
            var content = cell.defaultContentConfiguration()
            content.text = fridge.name
            content.image = UIImage(systemName: "refrigerator")
            cell.contentConfiguration = content
        }
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView, cellProvider: { cv, indexPath, fridge in
            cv.dequeueConfiguredReusableCell(using: regist, for: indexPath, item: fridge)
        })
    }
    
    private func applySnapshot(_ fridges: [Fridge]) {
        var snapshot = NSDiffableDataSourceSnapshot<Int,Fridge>()
        snapshot.appendSections([0])
        snapshot.appendItems(fridges)
        dataSource.apply(snapshot)
    }

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
        
        let settingsButton = UIButton(type: .system)
        settingsButton.setImage(UIImage(systemName: "gearshape", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
        settingsButton.tintColor = Theme.textPrimary
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [iconContainer, titleLabel, UIView(), searchButton, settingsButton])
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
    
    private func setupUI() {
        view.backgroundColor = Theme.background
        
        let stackView = UIStackView(arrangedSubviews: [makeBrandRow(), collectionView])
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fill
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            
        ])
    }
    
    @objc private func searchTapped() {
    }
    
    @objc private func settingsTapped() {
        #if DEBUG
        presentDebugMenu()
        #endif
    }

    #if DEBUG
    private func presentDebugMenu() {
        let sheet = UIAlertController(title: "Debug", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "清空 iCloud 與本機資料", style: .destructive) { [weak self] _ in
            self?.confirmCloudReset()
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        present(sheet, animated: true)
    }

    private func confirmCloudReset() {
        let alert = UIAlertController(
            title: "確定要清空？",
            message: "會刪除此 Apple ID 在雲端的所有冰箱 zone（含分享），並離開已加入的共享冰箱，同時清掉本機資料。Record Type 不受影響。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            self?.runCloudReset()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func runCloudReset() {
        guard let stack = (UIApplication.shared.delegate as? AppDelegate)?.sharedStack else { return }
        Task { @MainActor in
            let message: String
            do {
                let count = try await DebugCloudReset.resetAll(modelContainer: stack.container)
                message = "已刪除 \(count.private) 座自有 zone、離開 \(count.shared) 座共享 zone。\n請完全關閉 App 後重新開啟，會重建 Default 冰箱與 zone。"
            } catch {
                message = "清除失敗：\(error.localizedDescription)"
            }
            let done = UIAlertController(title: "Debug", message: message, preferredStyle: .alert)
            done.addAction(UIAlertAction(title: "好", style: .default))
            present(done, animated: true)
        }
    }
    #endif
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension FridgeSelectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let fridge = dataSource.itemIdentifier(for: indexPath) else { return }
        onSelect?(fridge)
    }
}
