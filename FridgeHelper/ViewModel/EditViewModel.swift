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
    static let units = ["pcs", "g", "kg", "ml", "oz"]

    // Inputs
    @Published var name: String
    @Published var quantity: Int
    @Published var unit: String
    @Published var expiryDate: Date
    @Published var isExpiryDateSet: Bool   // user must explicitly pick a date for new items
    @Published var memo: String
    @Published var selectedTag: String?
    @Published var storeLocation: String
    @Published var selectedImage: UIImage?

    // Output
    @Published private(set) var isFormValid: Bool = false

    // Available tags for the picker: ["未選擇"] + injected tags
    let availableTags: [String]

    let isEditing: Bool

    // Preserved timestamp for existing items (fixes notification re-scheduling bug)
    private let existingTimestamp: String?
    private let existingZoneOwnerName: String?
    private let existingUpdatedByName: String?

    init(existingItem: Item? = nil, availableTags: [String], defaultLocation: String = "冷藏") {
        self.availableTags = ["未選擇"] + availableTags
        self.isEditing = existingItem != nil
        self.existingTimestamp = existingItem?.timeStamp
        self.existingZoneOwnerName = existingItem?.zoneOwnerName
        self.existingUpdatedByName = existingItem?.updatedByName

        if let item = existingItem {
            self.name = item.name
            self.quantity = item.number
            self.unit = item.unit
            self.expiryDate = item.expiryDate
            self.isExpiryDateSet = true
            self.memo = item.memo ?? ""
            self.selectedTag = item.tag
            self.storeLocation = item.storeLocation.isEmpty
                ? Item.location(fromLegacy: item.storeCondition)
                : item.storeLocation
            self.selectedImage = item.image.flatMap { UIImage(data: $0) }
        } else {
            self.name = ""
            self.quantity = 1
            self.unit = Self.units[0]
            self.expiryDate = Date()
            self.isExpiryDateSet = false
            self.memo = ""
            self.selectedTag = nil
            self.storeLocation = defaultLocation
            self.selectedImage = nil
        }

        setupValidation()
    }

    private func setupValidation() {
        Publishers.CombineLatest($name, $isExpiryDateSet)
            .map { name, dateSet in !name.isEmpty && dateSet }
            .assign(to: &$isFormValid)
    }

    func buildItem() -> Item? {
        guard isFormValid else { return nil }
        let timestamp = existingTimestamp ?? dateController.shared.creatItemTimeStamp()
        return Item(
            name: name,
            number: quantity,
            unit: unit,
            expiryDate: expiryDate,
            storeLocation: storeLocation,
            memo: memo.isEmpty ? nil : memo,
            tag: selectedTag,
            image: selectedImage?.jpegData(compressionQuality: 0.5),
            timeStamp: timestamp,
            zoneOwnerName: existingZoneOwnerName,
            updatedByName: existingUpdatedByName
        )
    }
}
