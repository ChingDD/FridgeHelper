//
//  StatusBadge.swift
//  FridgeHelper
//

import UIKit

/// 食材狀態：已過期／剩 N 天（3 天內）／新鮮
enum ItemStatus {
    case expired
    case expiring(days: Int)
    case fresh

    /// 與 MainViewModel 的到期規則一致：3 天（259200 秒）內視為即將到期
    init(expiryDate: Date) {
        let interval = expiryDate.timeIntervalSinceNow
        if interval < 0 {
            self = .expired
        } else if interval <= 259200 {
            self = .expiring(days: max(1, Int(ceil(interval / 86400))))
        } else {
            self = .fresh
        }
    }

    var text: String {
        switch self {
        case .expired: return "已過期"
        case .expiring(let days): return "剩 \(days) 天"
        case .fresh: return "新鮮"
        }
    }

    var color: UIColor {
        switch self {
        case .expired: return Theme.danger
        case .expiring: return Theme.warningDeep
        case .fresh: return Theme.primaryDeep
        }
    }
}

final class StatusBadge: UILabel {
    private let insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

    var status: ItemStatus? {
        didSet {
            guard let status else { isHidden = true; return }
            isHidden = false
            text = status.text
            textColor = status.color
            backgroundColor = status.color.withAlphaComponent(0.15)
        }
    }

    init() {
        super.init(frame: .zero)
        font = Theme.font(12, .bold)
        clipsToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
