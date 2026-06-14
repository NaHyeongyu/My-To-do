import SwiftUI

enum MissionTheme {
    static let appBackground = Color(uiColor: .systemGroupedBackground)
    static let panel = Color(uiColor: .systemBackground)
    static let elevatedPanel = Color(uiColor: .secondarySystemGroupedBackground)
    static let controlFill = Color(uiColor: .tertiarySystemFill)
    static let graphite = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let accent = Color(uiColor: .label)
    static let selection = Color(uiColor: .label)
    static let eventBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .label
        }
    )
    static let eventForeground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .label : .systemBackground
        }
    )
    static let eventIndicator = Color(uiColor: .label)
    static let selectedText = Color(uiColor: .systemBackground)
    static let separator = Color(uiColor: .separator)
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .secondaryLabel)
    static let danger = Color(uiColor: .systemRed)

    static let radius: CGFloat = 8
}
