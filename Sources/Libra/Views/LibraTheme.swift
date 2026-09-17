import SwiftUI

/// Shared design tokens — glossy yellow on near-black. Every view pulls from
/// here so the app never mixes themes. macOS 14-safe APIs only.
enum LibraTheme {
    static let bg = Color(red: 0.043, green: 0.043, blue: 0.047)  // #0B0B0C
    static let panel = Color(red: 0.086, green: 0.086, blue: 0.09)  // #161617
    static let yellow = Color(red: 1.0, green: 0.839, blue: 0.039)  // #FFD60A
    static let gold = Color(red: 1.0, green: 0.765, blue: 0.0)  // #FFC300
    static let amber = Color(red: 0.722, green: 0.525, blue: 0.043)  // #B8860B

    /// Bright face of the glossy cards — yellow falling to gold.
    static var cardFace: LinearGradient {
        LinearGradient(
            colors: [yellow, gold, amber],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Hairline yellow border for dark panels.
    static var hairline: Color { yellow.opacity(0.15) }

    /// Soft ambient glow cast under glossy cards.
    static func ambient(hovering: Bool) -> Color {
        yellow.opacity(hovering ? 0.4 : 0.22)
    }
}

/// Glossy yellow card face: vertical gradient + top gloss highlight +
/// inner bottom shadow + soft yellow ambient shadow + hover lift/sweep.
/// Black text/icons sit on top — never yellow text on yellow.
struct LibraCardFace: View {
    var hovering: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(LibraTheme.cardFace)
            .overlay(alignment: .top) {
                // Gloss band — white highlight bleeding down from the top edge.
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(hovering ? 0.5 : 0.35),
                                Color.white.opacity(0.06),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 28)
            }
            .overlay(alignment: .bottom) {
                // Inner bottom shadow keeps the face from reading flat.
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.18)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                // Sweeping shine on hover — a diagonal shaft sliding across.
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.28), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.45)
                    .rotationEffect(.degrees(18))
                    .offset(x: hovering ? geo.size.width * 0.9 : -geo.size.width * 0.6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .animation(.easeInOut(duration: 0.45), value: hovering)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LibraTheme.amber.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: LibraTheme.ambient(hovering: hovering), radius: hovering ? 14 : 8, y: 3)
            .scaleEffect(hovering ? 1.02 : 1)
            .animation(.easeOut(duration: 0.18), value: hovering)
    }
}

/// Dark glass panel — ultraThinMaterial over near-black with a hairline
/// yellow border. Used for lists, map panels, and option strips.
struct LibraPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(LibraTheme.panel.opacity(0.9))
            .background(.ultraThinMaterial.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LibraTheme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func libraPanel() -> some View { modifier(LibraPanel()) }
}

/// Yellow gloss pill — black text, for the one primary action.
struct LibraPrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 5 : 8)
            .background(
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [LibraTheme.yellow, LibraTheme.gold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.45), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Dark glass pill — top gloss, hairline yellow edge that brightens on
/// hover, white text. For secondary actions (Back, Resolve, Undo, Cancel).
struct LibraSecondaryButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        SecondaryPill(label: configuration.label, isPressed: configuration.isPressed, compact: compact)
    }

    private struct SecondaryPill: View {
        let label: Configuration.Label
        let isPressed: Bool
        let compact: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            label
                .font(.system(size: compact ? 12 : 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, compact ? 12 : 16)
                .padding(.vertical, compact ? 5 : 8)
                .background(
                    ZStack {
                        Capsule().fill(LibraTheme.panel)
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color.white.opacity(hovering ? 0.18 : 0.10), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    }
                )
                .overlay(
                    Capsule().stroke(
                        hovering ? LibraTheme.yellow.opacity(0.5) : LibraTheme.hairline,
                        lineWidth: 1
                    )
                )
                .opacity(isEnabled ? (isPressed ? 0.7 : 1) : 0.5)
                .scaleEffect(isPressed ? 0.97 : 1)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }
}

/// Glossy dark pill for filename buttons — compact, gold on hover, used in
/// the GPS map overlay where names are the only affordance.
struct LibraFileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FilePill(label: configuration.label, isPressed: configuration.isPressed)
    }

    private struct FilePill: View {
        let label: Configuration.Label
        let isPressed: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            label
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(hovering ? LibraTheme.yellow : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    ZStack {
                        Capsule().fill(LibraTheme.panel)
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color.white.opacity(hovering ? 0.2 : 0.12), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                )
                .overlay(
                    Capsule().stroke(
                        hovering ? LibraTheme.yellow.opacity(0.6) : LibraTheme.hairline,
                        lineWidth: 1
                    )
                )
                .shadow(color: LibraTheme.yellow.opacity(hovering ? 0.25 : 0), radius: 6, y: 2)
                .opacity(isEnabled ? (isPressed ? 0.65 : 1) : 0.5)
                .scaleEffect(isPressed ? 0.96 : 1)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }
}

/// Preview/Live mode switch — gold circle-knob docked left next to a gold
/// edge while Preview only is on; flipping slides the knob right and the
/// track warms amber to signal the action button is armed.
struct PreviewModeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 9) {
            ZStack(alignment: configuration.isOn ? .leading : .trailing) {
                Capsule()
                    .fill(
                        configuration.isOn
                            ? LibraTheme.panel
                            : LibraTheme.amber.opacity(0.55)
                    )
                    .overlay(
                        Capsule().stroke(
                            configuration.isOn
                                ? LibraTheme.gold.opacity(0.8)
                                : LibraTheme.amber,
                            lineWidth: 1
                        )
                    )
                Circle()
                    .fill(
                        LinearGradient(
                            colors: configuration.isOn
                                ? [LibraTheme.yellow, LibraTheme.gold]
                                : [Color.white, Color(white: 0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.35), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 1.5, y: 1)
                    .frame(width: 16, height: 16)
                    .padding(3)
            }
            .frame(width: 40, height: 22)

            configuration.label
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.22)) {
                configuration.isOn.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
    }
}
