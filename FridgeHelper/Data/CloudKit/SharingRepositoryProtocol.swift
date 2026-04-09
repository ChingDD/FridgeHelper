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

    /// 刪除 zone share，停止共享。
    func stopSharing() async throws
}
