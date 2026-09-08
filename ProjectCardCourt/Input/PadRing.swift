import SwiftUI

/// The ring a pad leaves on whatever it is pointing at.
///
/// **Only ever drawn for a pad.** A finger points at a thing by touching it and needs no
/// cursor; a mark on the screen of somebody playing on glass is a mark that means nothing.
/// Every caller passes `Pad.shared.isAttached` through with it, so the whole game gains
/// and loses its cursor the moment a controller is plugged in or pulled out.
///
/// **One stroke, and still.** Nothing else in the game breathes, and the ring carries no
/// drop of its own: it sits over painted cards that already have theirs, and a second
/// shadow on top of those read as a card lifting rather than as a cursor.
struct PadRing: ViewModifier {
    var showing: Bool
    var corner: CGFloat
    var tint: Color = CardPalette.lightBlue

    private enum Ring {
        static let weight: CGFloat = 3
        /// How far outside the thing it sits, so it frames rather than covers.
        static let stand: CGFloat = 3
    }

    func body(content: Content) -> some View {
        content.overlay {
            if showing {
                RoundedRectangle(cornerRadius: corner + Ring.stand, style: .continuous)
                    .stroke(tint, lineWidth: Ring.weight)
                    .padding(-Ring.stand)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// The same ring round something with no corner to speak of.
struct PadPillRing: ViewModifier {
    var showing: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if showing {
                Capsule()
                    .stroke(CardPalette.lightBlue, lineWidth: 3)
                    .padding(-3)
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

    /// For a capsule, whose corner is whatever half its height turns out to be.
    func padRing(pill showing: Bool) -> some View {
        modifier(PadPillRing(showing: showing))
    }
}
