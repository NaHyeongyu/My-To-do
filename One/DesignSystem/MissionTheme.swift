import SwiftUI

enum MissionTheme {
    static let appBackground = adaptive(light: rgb(0.95, 0.96, 0.98), dark: rgb(0.06, 0.07, 0.09))
    static let panel = adaptive(light: .white, dark: rgb(0.09, 0.10, 0.12))
    static let elevatedPanel = adaptive(light: rgb(0.99, 0.995, 1.0), dark: rgb(0.12, 0.13, 0.16))
    static let controlFill = adaptive(light: rgb(0.91, 0.94, 0.96), dark: rgb(0.16, 0.18, 0.21))
    static let graphite = adaptive(light: rgb(0.08, 0.10, 0.12), dark: rgb(0.93, 0.95, 0.97))
    static let secondaryText = adaptive(light: rgb(0.28, 0.33, 0.38), dark: rgb(0.72, 0.76, 0.80))
    static let tertiaryText = adaptive(light: rgb(0.45, 0.50, 0.55), dark: rgb(0.56, 0.61, 0.66))
    static let accent = adaptive(light: rgb(0.02, 0.40, 0.52), dark: rgb(0.24, 0.73, 0.82))
    static let selection = accent
    static let accentSoft = adaptive(light: rgb(0.87, 0.95, 0.97), dark: rgb(0.08, 0.24, 0.29))
    static let eventBackground = adaptive(light: rgb(0.90, 0.96, 0.98), dark: rgb(0.09, 0.22, 0.27))
    static let eventForeground = adaptive(light: rgb(0.04, 0.24, 0.29), dark: rgb(0.88, 0.98, 1.0))
    static let eventSecondaryForeground = adaptive(light: rgb(0.18, 0.40, 0.46), dark: rgb(0.64, 0.84, 0.88))
    static let eventIndicator = accent
    static let selectedText = adaptive(light: .white, dark: rgb(0.03, 0.06, 0.07))
    static let floatingButtonSymbol = selectedText
    static let separator = adaptive(light: rgb(0.77, 0.82, 0.86), dark: rgb(0.26, 0.30, 0.35))
    static let success = adaptive(light: rgb(0.07, 0.48, 0.25), dark: rgb(0.28, 0.78, 0.45))
    static let successSoft = adaptive(light: rgb(0.87, 0.97, 0.90), dark: rgb(0.08, 0.25, 0.14))
    static let warning = adaptive(light: rgb(0.70, 0.38, 0.00), dark: rgb(0.95, 0.62, 0.22))
    static let danger = adaptive(light: rgb(0.74, 0.16, 0.20), dark: rgb(1.0, 0.42, 0.46))
    static let dangerSoft = adaptive(light: rgb(0.99, 0.89, 0.90), dark: rgb(0.30, 0.09, 0.11))

    static let radius: CGFloat = 8

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
