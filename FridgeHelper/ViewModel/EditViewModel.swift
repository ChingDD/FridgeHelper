//
//  EditViewModel.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/5/17.
//

import Foundation
import Combine
import UIKit

class EditViewModel {
    // Inputs
    @Published var name: String
    @Published var quantity: String
    @Published var expiryDate: Date
    @Published var isExpiryDateSet: Bool   // user must explicitly pick a date for new items
    @Published var memo: String
    @Published var selectedTag: String?
    @Published var storeConditionIndex: Int
    @Published var selectedImage: UIImage?

    // Output
    @Published private(set) var isFormValid: Bool = false

    // Available tags for the picker: ["未選擇"] + injected tags
    let availableTags: [String]

    // Preserved timestamp for existing items (fixes notification re-scheduling bug)
    private let existingTimestamp: String?
    private var cancellables = Set<AnyCancellable>()

    init(existingItem: Item? = nil, availableTags: [String]) {
        self.availableTags = ["未選擇"] + availableTags
        self.existingTimestamp = existingItem?.timeStamp

        if let item = existingItem {
            self.name = item.name
            self.quantity = "\(item.number)"
            self.expiryDate = item.expiryDate
            self.isExpiryDateSet = true
            self.memo = item.memo ?? ""
            self.selectedTag = item.tag
            self.storeConditionIndex = item.storeCondition
            self.selectedImage = item.image.flatMap { UIImage(data: $0) }
        } else {
            self.name = ""
            self.quantity = ""
            self.expiryDate = Date()
            self.isExpiryDateSet = false
            self.memo = ""
            self.selectedTag = nil
            self.storeConditionIndex = 0
            self.selectedImage = nil
        }

        setupValidation()
    }

    private func setupValidation() {
        Publishers.CombineLatest3($name, $quantity, $isExpiryDateSet)
            .map { name, qty, dateSet in !name.isEmpty && Int(qty) != nil && dateSet }
            .assign(to: &$isFormValid)
    }

    func buildItem() -> Item? {
        guard isFormValid else { return nil }
        let timestamp = existingTimestamp ?? dateController.shared.creatItemTimeStamp()
        return Item(
            name: name,
            number: Int(quantity)!,
            expiryDate: expiryDate,
            storeCondition: storeConditionIndex,
            memo: memo.isEmpty ? nil : memo,
            tag: selectedTag,
            image: selectedImage?.jpegData(compressionQuality: 0.5),
            timeStamp: timestamp
        )
    }
}
