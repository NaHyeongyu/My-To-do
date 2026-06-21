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
                    .stroke(MissionTheme.separator.opacity(0.42), lineWidth: 0.5)
            }
    }
}

struct MissionTimelineLiquidBandModifier: ViewModifier {
    private var shape: Rectangle {
        Rectangle()
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background {
                    MissionTheme.panel
                        .opacity(0.72)
                }
                .glassEffect(.regular.tint(MissionTheme.panel.opacity(0.42)), in: shape)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.white.opacity(0.22))
                        .frame(height: 0.7)
                        .blendMode(.plusLighter)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(MissionTheme.separator.opacity(0.34))
                        .frame(height: 0.5)
                }
        } else {
            content
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.white.opacity(0.20))
                        .frame(height: 0.7)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(MissionTheme.separator.opacity(0.34))
                        .frame(height: 0.5)
                }
        }
    }
}

struct MissionLiquidCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background {
                    MissionTheme.elevatedPanel
                        .opacity(0.74)
                        .clipShape(shape)
                }
                .glassEffect(.regular.tint(MissionTheme.panel.opacity(0.34)), in: shape)
                .overlay(alignment: .topLeading) {
                    shape
                        .stroke(.white.opacity(0.20), lineWidth: 0.7)
                        .blendMode(.plusLighter)
                }
                .overlay {
                    shape
                        .stroke(MissionTheme.separator.opacity(0.52), lineWidth: 0.75)
                }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(MissionTheme.elevatedPanel.opacity(0.82), in: shape)
                .overlay {
                    shape
                        .stroke(MissionTheme.separator.opacity(0.52), lineWidth: 0.75)
                }
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

    func missionLiquidCard(cornerRadius: CGFloat = MissionTheme.radius) -> some View {
        modifier(MissionLiquidCardModifier(cornerRadius: cornerRadius))
    }

    func missionTimelineLiquidBand() -> some View {
        modifier(MissionTimelineLiquidBandModifier())
    }

    func missionLiquidButton(_ variant: MissionButtonVariant = .regular) -> some View {
        modifier(MissionLiquidButtonModifier(variant: variant))
    }

    func dialogBackdrop(isPresented: Bool, opacity: Double = 0.34) -> some View {
        modifier(DialogBackdropModifier(isPresented: isPresented, opacity: opacity))
    }
}
