import SwiftUI

enum MissionButtonVariant {
    case regular
    case prominent
}

struct MissionCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(MissionTheme.panel, in: RoundedRectangle(cornerRadius: MissionTheme.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MissionTheme.radius, style: .continuous)
                    .stroke(MissionTheme.separator.opacity(0.34), lineWidth: 0.5)
            }
    }
}

struct MissionLiquidButtonModifier: ViewModifier {
    let variant: MissionButtonVariant

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch variant {
            case .regular:
                content
                    .buttonStyle(.glass)
            case .prominent:
                content
                    .buttonStyle(.glassProminent)
            }
        } else {
            switch variant {
            case .regular:
                content
                    .buttonStyle(.bordered)
            case .prominent:
                content
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

extension View {
    func missionCard() -> some View {
        modifier(MissionCardModifier())
    }

    func missionLiquidButton(_ variant: MissionButtonVariant = .regular) -> some View {
        modifier(MissionLiquidButtonModifier(variant: variant))
    }
}
