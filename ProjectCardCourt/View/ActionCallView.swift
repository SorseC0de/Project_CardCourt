import SwiftUI

extension ActionCall {
    /// White throughout, and the drop does the telling. Four names in four colours would
    /// have every call shouting its own way; one voice with four accents reads as one
    /// game speaking.
    var drop: Color {
        switch self {
        case .inbound:   return CardPalette.blue
        case .gameBreak: return CardPalette.magenta
        case .injury:    return CardPalette.gray
        case .whistle:   return CardPalette.red
        case .clamped:   return CardPalette.purple
        }
    }

    /// What the streaks behind the words are made of. The call's own colour where it has
    /// one, and the table's kit colours where the call is the game's rather than a card's.
    var streak: Color? {
        switch self {
        case .gameBreak: return CardPalette.magenta
        case .injury:    return CardPalette.gray
        case .whistle:   return .white
        case .clamped:   return CardPalette.red
        case .inbound: return nil
        }
    }

    /// The one exception to the white. A Clamp is the only call that is something being
    /// done *to* the player rather than something the game is doing, and red over purple
    /// is what the coils on the floor already say.
    var ink: Color {
        self == .clamped ? CardPalette.red : .white
    }
}


/// The call, held for a beat and then gone.
struct ActionCallView: View {
    let call: ActionCall
    /// Who is on him, shown under the line. Empty for every call but `.clamped`.
    var clamps: [ClampBrief] = []
    var onFinished: () -> Void

    @State private var leaving = false

    var body: some View {
        ZStack {
            if call.dims {
                DimLayer(on: !leaving, amount: Theme.dimCall)
            }
            card
        }
        // Nothing underneath is live while the game is speaking. The card and its dim
        // both stand aside for hit testing, so with the rebound board now raised behind
        // the call a bid could be tapped in before the call had finished making it.
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    private var card: some View {
        ModeCardView(title: call.title,
                     subtitle: call.blurb,
                     ink: call.ink,
                     subtitleInk: call.drop,
                     streakInk: call.streak,
                     emblem: call.emblem,
                     accessory: clamps.isEmpty ? nil
                                : AnyView(ClampRosterView(clamps: clamps)),
                     isLeaving: leaving,
                     onLanded: {},
                     onFinished: onFinished)
            // Auto-dismiss. There is nothing here to agree to.
            //
            // Keyed, and `leaving` reset with it: an unkeyed task runs once for the life
            // of the view, so a second call landing on a view SwiftUI had kept alive would
            // never raise `leaving` — and `announce` waits on that, forever.
            .task(id: call) {
                leaving = false
                try? await Task.sleep(for: .seconds(Pacing.actionCall))
                leaving = true
            }
    }
}

#if DEBUG
#Preview("Action call") {
    /// **Every call the game can make**, not only the ones that are `ActionCall`s — the
    /// round slab and the half's Z card are announcements too, and a bench that leaves
    /// them out is a bench you have to remember the gaps in.
    struct Bench: View {
        @State private var call: ActionCall?
        @State private var round: RoundCall?
        var body: some View {
            ZStack {
                Theme.courtFloor.ignoresSafeArea()
                if let call {
                    ActionCallView(call: call) { self.call = nil }
                } else if let round {
                    RoundCallView(call: round) { self.round = nil }
                        .onTapGesture { self.round = nil }
                } else {
                    VStack(spacing: 10) {
                        ForEach(ActionCall.allCases) { one in
                            ChunkyButton(title: one.title) { call = one }
                        }
                        ChunkyButton(title: "Round 3", fill: CardPalette.blue,
                                     stroke: CardPalette.gold,
                                     shade: CardPalette.orange) {
                            round = RoundCall(round: 3)
                        }
                        ChunkyButton(title: "Halftime", fill: CardPalette.black,
                                     stroke: CardPalette.gray,
                                     shade: CardPalette.navy) {
                            round = RoundCall(round: 4, isHalftime: true)
                        }
                    }
                    .padding(40)
                }
            }
        }
    }
    return Bench()
}
#endif
