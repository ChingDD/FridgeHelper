//
//  ParticipantsViewController.swift
//  FridgeHelper
//
//  成員頁：顯示共享冰箱的成員清單，邀請／移除透過系統 UICloudSharingController
//

import UIKit
import CloudKit
import Combine

final class ParticipantsViewController: UIViewController {

    var viewModel: ParticipantsViewModel!

    private var cancellables = Set<AnyCancellable>()

    private let syncStatusLabel = UILabel()
    private let inviteButton = UIButton(configuration: .filled())
    private let membersStack = UIStackView()
    private let stateLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        title = "成員"
        navigationController?.navigationBar.prefersLargeTitles = true

        setupLayout()
        setupBindings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refresh()
    }

    // MARK: - Setup

    private func setupLayout() {
        // 使用者卡片
        let userCard = CardView(background: Theme.primary.withAlphaComponent(0.12))

        let avatar = UILabel()
        avatar.text = String(UIDevice.current.name.prefix(1))
        avatar.font = Theme.font(28, .bold)
        avatar.textColor = .white
        avatar.textAlignment = .center
        avatar.backgroundColor = Theme.primary
        avatar.layer.cornerRadius = 32
        avatar.clipsToBounds = true
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.widthAnchor.constraint(equalToConstant: 64).isActive = true
        avatar.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let deviceLabel = UILabel()
        deviceLabel.text = UIDevice.current.name
        deviceLabel.font = Theme.font(20, .bold)
        deviceLabel.textColor = Theme.textPrimary
        deviceLabel.textAlignment = .center

        syncStatusLabel.font = Theme.font(14, .medium)
        syncStatusLabel.textColor = Theme.primaryDeep
        syncStatusLabel.textAlignment = .center

        let userStack = UIStackView(arrangedSubviews: [avatar, deviceLabel, syncStatusLabel])
        userStack.axis = .vertical
        userStack.alignment = .center
        userStack.spacing = 8
        userStack.translatesAutoresizingMaskIntoConstraints = false
        userCard.contentView.addSubview(userStack)

        // 家庭共享標題列＋邀請按鈕
        let sectionLabel = UILabel()
        sectionLabel.text = "家庭共享"
        sectionLabel.font = Theme.font(22, .bold)
        sectionLabel.textColor = Theme.textPrimary

        inviteButton.configuration?.baseBackgroundColor = Theme.primaryDeep
        inviteButton.configuration?.baseForegroundColor = .white
        inviteButton.configuration?.image = UIImage(systemName: "person.badge.plus")
        inviteButton.configuration?.imagePadding = 6
        inviteButton.configuration?.attributedTitle = AttributedString(
            "邀請",
            attributes: AttributeContainer([.font: Theme.font(15, .bold)])
        )
        inviteButton.configuration?.cornerStyle = .capsule
        inviteButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        inviteButton.addTarget(self, action: #selector(inviteTapped), for: .touchUpInside)

        let sectionRow = UIStackView(arrangedSubviews: [sectionLabel, UIView(), inviteButton])
        sectionRow.alignment = .center

        // 成員清單
        membersStack.axis = .vertical
        membersStack.spacing = 12

        stateLabel.font = Theme.font(14)
        stateLabel.textColor = Theme.textSecondary
        stateLabel.numberOfLines = 0
        stateLabel.textAlignment = .center

        let contentStack = UIStackView(arrangedSubviews: [userCard, sectionRow, membersStack, stateLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            userStack.topAnchor.constraint(equalTo: userCard.contentView.topAnchor, constant: 28),
            userStack.bottomAnchor.constraint(equalTo: userCard.contentView.bottomAnchor, constant: -28),
            userStack.leadingAnchor.constraint(equalTo: userCard.contentView.leadingAnchor, constant: 16),
            userStack.trailingAnchor.constraint(equalTo: userCard.contentView.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Theme.spacing),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Theme.spacing),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.spacing),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.spacing),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -Theme.spacing * 2),
        ])
    }

    private func setupBindings() {
        viewModel.$accountStatusText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in self?.syncStatusLabel.text = text }
            .store(in: &cancellables)

        Publishers.CombineLatest(viewModel.$state, viewModel.$members)
            .receive(on: RunLoop.main)
            .sink { [weak self] state, members in self?.render(state: state, members: members) }
            .store(in: &cancellables)
    }

    private func render(state: ParticipantsViewModel.State, members: [ParticipantsViewModel.Member]) {
        inviteButton.isHidden = !viewModel.canInvite
        membersStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        members.forEach { membersStack.addArrangedSubview(makeMemberRow($0)) }

        switch state {
        case .loading:
            stateLabel.text = "載入中…"
        case .notSharing:
            stateLabel.text = "尚未共享冰箱\n點擊「邀請」與家人共同管理"
        case .error(let message):
            stateLabel.text = "載入成員失敗：\(message)"
        case .owner, .participant:
            stateLabel.text = nil
        }
        stateLabel.isHidden = (stateLabel.text ?? "").isEmpty
    }

    private func makeMemberRow(_ member: ParticipantsViewModel.Member) -> UIView {
        let card = CardView(background: Theme.surface, cornerRadius: Theme.cornerButton)

        let nameLabel = UILabel()
        nameLabel.text = member.isMe ? "\(member.name)（我）" : member.name
        nameLabel.font = Theme.font(16, .semibold)
        nameLabel.textColor = member.isPending ? Theme.textSecondary : Theme.textPrimary

        let roleBadge = StatusBadge()
        if member.isOwner {
            roleBadge.text = "擁有者"
            roleBadge.textColor = Theme.primaryDeep
            roleBadge.backgroundColor = Theme.primary.withAlphaComponent(0.15)
        } else if member.isPending {
            roleBadge.text = "待接受"
            roleBadge.textColor = Theme.warningDeep
            roleBadge.backgroundColor = Theme.warning.withAlphaComponent(0.2)
        } else {
            roleBadge.text = "已加入"
            roleBadge.textColor = Theme.primaryDeep
            roleBadge.backgroundColor = Theme.primary.withAlphaComponent(0.15)
        }

        let row = UIStackView(arrangedSubviews: [nameLabel, UIView(), roleBadge])
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
        ])
        return card
    }

    // MARK: - Invite

    @objc private func inviteTapped() {
        Task { @MainActor in
            do {
                let (share, container) = try await viewModel.shareManager.fetchOrCreateShare()
                let sharingController = UICloudSharingController(share: share, container: container)
                sharingController.delegate = self
                sharingController.availablePermissions = [.allowReadWrite, .allowPrivate]
                present(sharingController, animated: true)
            } catch {
                let alert = UIAlertController(title: "分享失敗", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "確定", style: .default))
                present(alert, animated: true)
            }
        }
    }
}

// MARK: - UICloudSharingControllerDelegate

extension ParticipantsViewController: UICloudSharingControllerDelegate {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        let alert = UIAlertController(title: "儲存分享失敗", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        viewModel.refresh()
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        viewModel.refresh()
    }

    func itemTitle(for csc: UICloudSharingController) -> String? { "我的冰箱" }
}
