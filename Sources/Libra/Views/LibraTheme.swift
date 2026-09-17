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
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Dark glass pill — hairline yellow edge, white text, for secondary actions.
struct LibraSecondaryButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 5 : 8)
            .background(
                Capsule()
                    .fill(LibraTheme.panel)
                    .overlay(
                        Capsule().stroke(LibraTheme.hairline, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
