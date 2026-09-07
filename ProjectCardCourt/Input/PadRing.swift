import SwiftUI

/// The ring a pad leaves on whatever it is pointing at.
///
/// **Only ever drawn for a pad.** A finger points at a thing by touching it and needs no
/// cursor; a mark on the screen of somebody playing on glass is a mark that means nothing.
/// Every caller passes `Pad.shared.isAttached` through with it, so the whole game gains
/// and loses its cursor the moment a controller is plugged in or pulled out.
///
/// **Hard, and still.** Every other mark in this game is a flat shape with a hard
/// south-east drop and none of them breathe — a pulsing cursor would be the one animated
/// border on a screen of painted card.
struct PadRing: ViewModifier {
    var showing: Bool
    var corner: CGFloat
    var tint: Color = CardPalette.gold
    var drop: Color = CardPalette.orange

    private enum Ring {
        static let weight: CGFloat = 3
        /// South-east, and three deep like every other drop in the game.
        static let drop: CGFloat = 3
        /// How far outside the thing it sits, so it frames rather than covers.
        static let stand: CGFloat = 3
    }

    func body(content: Content) -> some View {
        content.overlay {
            if showing {
                RoundedRectangle(cornerRadius: corner + Ring.stand, style: .continuous)
                    .stroke(tint, lineWidth: Ring.weight)
                    .shadow(color: drop, radius: 0, x: Ring.drop, y: Ring.drop)
                    .padding(-Ring.stand)
                    .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    /// Rings this if the pad is pointing at it. The corner is the thing's own, so a card
    /// is ringed as a card and a pill as a pill.
    func padRing(_ showing: Bool, corner: CGFloat) -> some View {
        modifier(PadRing(showing: showing, corner: corner))
    }
}
