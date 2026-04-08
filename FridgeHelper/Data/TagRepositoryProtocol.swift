//
//  TagRepositoryProtocol.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/8.
//

import Foundation

protocol TagRepositoryProtocol {
    func fetchTags() -> [String]
    func saveTags(_ tags: [String])
}
