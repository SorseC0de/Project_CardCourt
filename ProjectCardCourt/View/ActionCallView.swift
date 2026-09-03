import SwiftUI

/// A phase or event announcing itself across the screen.
///
/// The bars are Project Stars' — see `ModeCardView` — and the lettering is ours. What is
/// different here is that nothing is being chosen: a mode card in Stars waits for a Start
/// button, and this one is telling you what just happened, so it leaves on its own.
enum ActionCall: String, Identifiable, Equatable, CaseIterable {
    case inbound, rebound, gameBreak, whistle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbound:   return "Inbound"
        case .rebound:   return "Rebound"
        case .gameBreak: return "Game Break"
        case .whistle:   return "Whistle"
        }
    }

    /// The line under it. What the call means, not what it is called.
    var blurb: String {
        switch self {
        case .inbound:   return "Put it back in play"
        case .rebound:   return "The board is live"
        case .gameBreak: return "Nobody played this"
        case .whistle:   return "Play stops"
        }
    }

    /// White throughout, and the drop does the telling. Four names in four colours would
    /// have every call shouting its own way; one voice with four accents reads as one
    /// game speaking.
    var drop: Color {
        switch self {
        case .inbound:   return CardPalette.blue
        case .rebound:   return CardPalette.orange
        case .gameBreak: return CardPalette.purple
        case .whistle:   return CardPalette.red
        }
    }
}

/// The call, held for a beat and then gone.
struct ActionCallView: View {
    let call: ActionCall
    var onFinished: () -> Void

    @State private var leaving = false

    var body: some View {
        ModeCardView(title: call.title,
                     subtitle: call.blurb,
                     ink: .white,
                     subtitleInk: call.drop,
                     isLeaving: leaving,
                     onLanded: {},
                     onFinished: onFinished)
            // Auto-dismiss. There is nothing here to agree to.
            .task {
                try? await Task.sleep(for: .seconds(Pacing.actionCall))
                leaving = true
            }
    }
}

#if DEBUG
#Preview("Action call") {
    struct Bench: View {
        @State private var call: ActionCall? = .inbound
        var body: some View {
            ZStack {
                Theme.courtFloor.ignoresSafeArea()
                if let call {
                    ActionCallView(call: call) { self.call = nil }
                } else {
                    VStack(spacing: 10) {
                        ForEach(ActionCall.allCases) { one in
                            ChunkyButton(title: one.title) { call = one }
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
