//
//  ParticipantsViewModel.swift
//  FridgeHelper
//

import Foundation
import CloudKit
import Combine

@MainActor
class ParticipantsViewModel {

    enum State {
        case loading
        case notSharing
        case owner
        case participant
        case error(String)
    }

    struct Member {
        let name: String
        let isOwner: Bool
        let isMe: Bool
        let isPending: Bool
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var members: [Member] = []
    @Published private(set) var accountStatusText = "檢查 iCloud 狀態中…"

    let shareManager: SharingRepositoryProtocol
    private let ckContainer = CKContainer(identifier: "iCloud.FridgeHelper")

    /// 只有 owner（或尚未分享的擁有者）能發出邀請；participant 唯讀
    var canInvite: Bool {
        switch state {
        case .owner, .notSharing: return true
        default: return false
        }
    }

    init(shareManager: SharingRepositoryProtocol) {
        self.shareManager = shareManager
    }

    func refresh() {
        Task {
            do {
                if let share = try await shareManager.fetchExistingShare() {
                    members = Self.mapMembers(of: share)
                    state = .owner
                } else if let share = try await shareManager.fetchParticipatingShare() {
                    members = Self.mapMembers(of: share)
                    state = .participant
                } else {
                    members = []
                    state = .notSharing
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
        Task {
            let status = (try? await ckContainer.accountStatus()) ?? .couldNotDetermine
            accountStatusText = status == .available ? "iCloud 同步已啟用" : "iCloud 尚未登入"
        }
    }

    private static func mapMembers(of share: CKShare) -> [Member] {
        share.participants.map { participant in
            Member(
                name: participant.displayName,
                isOwner: participant.role == .owner,
                isMe: participant == share.currentUserParticipant,
                isPending: participant.acceptanceStatus != .accepted
            )
        }
    }
}
