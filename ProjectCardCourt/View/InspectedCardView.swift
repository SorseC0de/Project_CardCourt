import SwiftUI

/// A slotted card raised to be read.
///
/// Grows out of the slot that was tapped rather than appearing in the middle of the
/// screen. With three Intangibles and up to three Clamps on the board at once, a card
/// arriving from nowhere makes you work out which one you asked for; arriving from its
/// own slot answers that before you can ask.
struct InspectedCardView: View {
    let card: CardDescriptor
    /// The slot's centre, in global coordinates.
    let from: CGPoint

    @State private var arrived = false

    var body: some View {
        GeometryReader { geo in
            CardFrontView(descriptor: card, displayWidth: 96, expanded: true)
                .scaleEffect(arrived ? 2 : 0.3)
                .opacity(arrived ? 1 : 0)
                .position(arrived
                          ? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                          : from)
                .shadow(color: .black.opacity(0.55), radius: 22, y: 12)
        }
        .allowsHitTesting(false)
        .task {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) { arrived = true }
        }
    }
}

extension View {
    /// Taps this card up out of wherever it is sitting.
    ///
    /// The point handed back is the card's own centre on screen, because
    /// `InspectedCardView` grows out of the place that was tapped — a card arriving from
    /// nowhere makes you work out which one you asked for.
    @ViewBuilder
    func raisable(_ card: CardDescriptor,
                  _ onSelect: ((CardDescriptor, CGPoint) -> Void)?) -> some View {
        if let onSelect {
            overlay {
                GeometryReader { slot in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(card, CGPoint(x: slot.frame(in: .global).midX,
                                                   y: slot.frame(in: .global).midY))
                        }
                }
            }
        } else {
            self
        }
    }
}
