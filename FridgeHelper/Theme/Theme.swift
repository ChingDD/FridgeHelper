//
//  Theme.swift
//  FridgeHelper
//

import UIKit

enum Theme {
    // MARK: - Colors
    static let primary = UIColor(hex: 0x00A896)
    static let primaryDeep = UIColor(hex: 0x006B5F)
    static let warning = UIColor(hex: 0xFF8C42)
    static let warningDeep = UIColor(hex: 0x9B4500)
    static let danger = UIColor(hex: 0xD0342C)
    static let freezerAccent = UIColor(hex: 0x4361EE)

    static let background = dynamic(light: 0xF8FAFB, dark: 0x111415)
    static let surface = dynamic(light: 0xF2F4F5, dark: 0x1C2021)
    static let surfaceElevated = dynamic(light: 0xFFFFFF, dark: 0x24292A)
    static let textPrimary = dynamic(light: 0x191C1D, dark: 0xE9E9E9)
    static let textSecondary = dynamic(light: 0x5C6B6D, dark: 0x9BA3A5)

    // MARK: - Metrics
    static let cornerCard: CGFloat = 24
    static let cornerButton: CGFloat = 16
    static let spacing: CGFloat = 16

    // MARK: - Fonts
    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    // MARK: - Shadow
    static func applyAmbientShadow(to view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.06
        view.layer.shadowRadius = 14
        view.layer.shadowOffset = CGSize(width: 0, height: 6)
    }

    private static func dynamic(light: Int, dark: Int) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }
}

extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
