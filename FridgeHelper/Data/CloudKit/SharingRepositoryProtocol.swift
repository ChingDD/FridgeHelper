//
//  SharingRepositoryProtocol.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/9.
//

import Foundation
import CloudKit

protocol SharingRepositoryProtocol {
    /// 取回已存在的 zone share，或建立新的。
    /// 回傳值可直接用於 UICloudSharingController。
    func fetchOrCreateShare() async throws -> (CKShare, CKContainer)

    /// 取回自己 private zone 已存在的 share（沒有分享過則為 nil）。
    func fetchExistingShare() async throws -> CKShare?

    /// participant 裝置：取回被邀請加入的 zone-wide share（未加入任何共享則為 nil）。
    func fetchParticipatingShare() async throws -> CKShare?

    /// 刪除 zone share，停止共享。
    func stopSharing() async throws
}
