import SwiftUI

/// Where the court's frame gets published, so anything drawn over the whole screen can
/// still place things by the court's own geometry.
struct CourtFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// Everything goes dark except the people you can throw to.
///
/// The players are drawn again here rather than lifted out of the court. The court is one
/// cell of a stack and the hand is another below it, so there is no single layer that sits
/// over the cards and under the figures — and a second copy, placed by the court's own
/// geometry, costs four sprites and no rearranging of anything that already works.
struct InboundOverlay: View {
    let state: GameState
    var viewer: Seat = GameRules.localSeat
    /// The court's frame in global space, from `CourtFrameKey`.
    let court: CGRect
    var onSelect: (Seat) -> Void

    private var inbounder: Seat? {
        if case .inbound(let seat) = state.phase { return seat }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            let court = CourtGeometry(size: self.court.size, viewer: viewer)
            // The court's own origin, in this view's space.
            let origin = CGPoint(x: self.court.minX - geo.frame(in: .global).minX,
                                 y: self.court.minY - geo.frame(in: .global).minY)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.black.opacity(0.66))
                    .ignoresSafeArea()

                ForEach(Seat.allCases, id: \.self) { seat in
                    if seat != inbounder {
                        let footing = court.footing(of: seat)
                        Button { onSelect(seat) } label: {
                            // Waiting, not running. Everybody is stood still during an
                            // inbound, which is also why the streaks stop.
                            InbounderFigure(seat: seat, sprite: .inboundReceiver)
                                .scaleEffect(court.scale(of: seat), anchor: .bottom)
                                .frame(width: Theme.Figure.height, height: Theme.Figure.height,
                                       alignment: .top)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: origin.x + footing.x,
                                  y: origin.y + footing.y - Theme.Figure.height / 2
                                     + Theme.Figure.height * Perspective.playerDrop)
                    }
                }

                // The one throwing it in, off the floor. His running figure on the court
                // is hidden while this is up, so there is only ever one of him.
                if let inbounder {
                    let depth = Perspective.inbounderDepth
                    InbounderFigure(seat: inbounder)
                        .scaleEffect(court.scale(at: depth), anchor: .bottom)
                        .position(x: origin.x + court.centreX
                                  + court.halfWidth(at: depth) * Perspective.inbounderLateral,
                                  y: origin.y + court.y(at: depth)
                                     - Theme.Figure.height / 2
                                     + Theme.Figure.height * Perspective.playerDrop)
                }

                prompt
            }
        }
    }

    /// Two lines, and the second is the quiet one — the instruction is "pick somebody",
    /// and why is a footnote to it. `Inbound` is picked out because it is the only word in
    /// the sentence that is a rule rather than English.
    private var prompt: some View {
        VStack(alignment: .leading, spacing: 0) {
            ActionText("Select a Player", size: 46)
            ActionText(runs: [.init("to "),
                              .init("Inbound", ink: CardPalette.gold, drop: CardPalette.orange),
                              .init(" to!")],
                       size: 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
        .allowsHitTesting(false)
    }
}
