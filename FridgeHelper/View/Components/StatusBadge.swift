//
//  StatusBadge.swift
//  FridgeHelper
//

import UIKit

/// 食材狀態：已過期／剩 N 天（3 天內）／新鮮
enum ItemStatus {
    case expired(days: Int)
    case expiring(days: Int)
    case fresh(days: Int)

    /// 與 MainViewModel 的到期規則一致：3 天（259200 秒）內視為即將到期
    init(expiryDate: Date) {
        let interval = expiryDate.timeIntervalSinceNow
        let days = max(1, Int(abs(ceil(interval / 86400))))
        if interval < 0 {
            self = .expired(days: days)
        } else if interval <= 259200 {
            self = .expiring(days: days)
        } else {
            self = .fresh(days: days)
        }
    }

    var title: String {
        switch self {
        case .expired: return "過期"
        case .fresh, .expiring: return "剩於"
        }
    }

    var days: Int {
        switch self {
        case .expired(let days), .expiring(let days), .fresh(let days): return days
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
    private let insets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

    var status: ItemStatus? {
        didSet {
            guard let status else { isHidden = true; return }
            isHidden = false
            attributedText = Self.makeText(for: status)
            backgroundColor = status.color.withAlphaComponent(0.15)
        }
    }

    init() {
        super.init(frame: .zero)
        font = Theme.font(12, .bold)
        numberOfLines = 0
        textAlignment = .center
        clipsToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func makeText(for status: ItemStatus) -> NSAttributedString {
        // attributedText 會蓋掉 label 的 textAlignment，置中得寫進 paragraphStyle
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        func part(_ string: String, _ size: CGFloat) -> NSAttributedString {
            NSAttributedString(string: string, attributes: [
                .font: Theme.font(size, .bold),
                .foregroundColor: status.color,
                .paragraphStyle: paragraph,
            ])
        }

        let result = NSMutableAttributedString(attributedString: part("\(status.title)\n", 11))
        result.append(part("\(status.days)\n", 22))
        result.append(part("天", 11))
        return result
    }

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
