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
    static let selection = accent
    static let accentSoft = Color(uiColor: .tertiarySystemFill)
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
    static let eventSecondaryForeground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .secondaryLabel : .systemBackground
        }
    )
    static let eventIndicator = accent
    static let selectedText = Color(uiColor: .systemBackground)
    static let floatingButtonSymbol = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .black : .systemBackground
        }
    )
    static let separator = Color(uiColor: .separator)
    static let success = Color(uiColor: .systemGreen)
    static let successSoft = Color(uiColor: .systemGreen).opacity(0.16)
    static let warning = Color(uiColor: .systemOrange)
    static let info = Color(uiColor: .systemBlue)
    static let infoSoft = Color(uiColor: .systemBlue).opacity(0.16)
    static let danger = Color(uiColor: .systemRed)
    static let dangerSoft = Color(uiColor: .systemRed).opacity(0.16)

    static let radius: CGFloat = 8
}
