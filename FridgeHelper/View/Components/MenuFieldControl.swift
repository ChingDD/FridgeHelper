//
//  MenuFieldControl.swift
//  FridgeHelper
//

import UIKit

/// 文字框樣式的選單控制項：顯示目前值，點擊彈出 UIMenu。
/// 用於儲存位置／標籤篩選與表單選擇器。
final class MenuFieldControl: UIButton {

    init(value: String) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = Theme.surface
        config.baseForegroundColor = Theme.textPrimary
        config.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.background.cornerRadius = Theme.cornerButton
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        configuration = config
        contentHorizontalAlignment = .leading
        showsMenuAsPrimaryAction = true
        setValue(value)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValue(_ value: String) {
        configuration?.attributedTitle = AttributedString(
            value,
            attributes: AttributeContainer([.font: Theme.font(15, .semibold)])
        )
    }
}
