//
//  FormFieldView.swift
//  FridgeHelper
//

import UIKit

/// 表單欄位：小型大寫風格標題＋任意欄位視圖
final class FormFieldView: UIStackView {

    init(title: String, field: UIView) {
        super.init(frame: .zero)
        axis = .vertical
        spacing = 8

        let label = UILabel()
        label.text = title
        label.font = Theme.font(12, .bold)
        label.textColor = Theme.textSecondary

        addArrangedSubview(label)
        addArrangedSubview(field)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
