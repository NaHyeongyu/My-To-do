import SwiftUI

enum MissionButtonVariant {
    case regular
    case prominent
}

struct MissionCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(MissionTheme.elevatedPanel, in: RoundedRectangle(cornerRadius: MissionTheme.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MissionTheme.radius, style: .continuous)
                    .stroke(MissionTheme.separator.opacity(0.72), lineWidth: 1)
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

struct DialogBackdropModifier: ViewModifier {
    let isPresented: Bool
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    Color.black
                        .opacity(opacity)
                        .ignoresSafeArea()
                        .frame(width: 10_000, height: 10_000)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isPresented)
    }
}

extension View {
    func missionCard() -> some View {
        modifier(MissionCardModifier())
    }

    func missionLiquidButton(_ variant: MissionButtonVariant = .regular) -> some View {
        modifier(MissionLiquidButtonModifier(variant: variant))
    }

    func dialogBackdrop(isPresented: Bool, opacity: Double = 0.34) -> some View {
        modifier(DialogBackdropModifier(isPresented: isPresented, opacity: opacity))
    }
}
