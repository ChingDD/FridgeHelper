//
//  FridgeSelectionViewController.swift
//  FridgeHelper
//
//  Created by 姐夫 on 2026/9/26.
//

import UIKit

class FridgeSelectionViewController: UIViewController {
    
    var viewModel: FridgeViewModel!
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let config = UICollectionView
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupUI()
        // Do any additional setup after loading the view.
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.backgroundColor = .yellow
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
    }
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
    
}
