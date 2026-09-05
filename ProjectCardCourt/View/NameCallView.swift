import SwiftUI

// Ported from Project Stars, where the same shape announces that a passive fired. Kept
// whole for the same reason `ModeCardView` was: the movement is the part worth having.
// Only what it says is ours — there it names an effect, here it names a person.

/// One name, waiting its turn or taking it.
struct NameCall: Identifiable, Equatable {
    let id = UUID()
    let seat: Seat
    /// The line the name is saying, if it is saying one. Nil is just the name.
    var note: String?
}

/// The mode card's upper bar, shrunk down and sent across the top of the screen.
///
/// ## What it is for
///
/// A cutscene that does not show the player, or shows them too close to put a name under
/// their feet, still has to say whose moment this is. A plate under a figure cannot do
/// that; this crosses the screen above the scene and is gone.
///
/// ## Why it is the same shape
///
/// Because it is the same voice. The mode card says what is happening; this says who it
/// is happening to. Drawn as its own thing it would be a second visual language on one
/// screen, where a smaller copy of a shape the player has already been shown reads
/// immediately as *the game telling you something*.
///
/// It keeps the mother shape's slant and its tail taper, and it travels the way she does
/// — in from the leading edge, out past the trailing one. It never comes back the way it
/// came, and it is gone before the middle of the screen: there is a scene underneath it.
struct NameCallView: View {
    let call: NameCall

    /// How far out it flies. Hand it the screen's width: unlike the port, this one is
    /// meant to cross the whole thing.
    let reach: CGFloat

    /// Raised by the scene when it is nearly over, which is when the plate starts its trip
    /// out. In Stars it kept its own clock; here it belongs to whatever it is naming, and
    /// a name that leaves before the scene does has stopped saying anything.
    var isLeaving = false

    var onFinished: () -> Void = {}

    @State private var stage: Stage = .offstage

    /// Where it is, and what it is doing.
    private enum Stage {
        case offstage, held, leaving
    }

    /// When it began leaving, or nil while it is still arriving or held.
    @State private var leftAt: Date?

    var body: some View {
        let size = NameCallStyle.size(reaching: reach)

        // Ticking only while it is leaving. Nothing else here needs a frame clock, and a
        // clock running the whole time the card is up is a clock running for nothing.
        TimelineView(.animation(paused: leftAt == nil)) { timeline in
            // **The word is an overlay on the plate, not a sibling beside it.** As two
            // children of a stack their widths were negotiated against each other, and
            // the pair came out side by side with the plate pushed off the leading edge.
            // Hung on the plate it can only ever be on the plate.
            face
                .frame(width: size.width, height: size.height)
                .overlay { SideStreaks(ink: .white, thickness: StreakStyle.sideThicknessSmall).mask { face } }
                .overlay(alignment: .leading) {
                    word(burning: burn(at: timeline.date, rate: wordRate))
                }
            .opacity(stage == .offstage ? 0 : 1)
            // Leaving: **not animated at all.** Opacity is spent per tick at a rate of its
            // own, so how fast it disappears has nothing to do with how fast it travels.
            // An animation here governs the whole subtree, which is what retimed the slide.
            .opacity(burn(at: timeline.date, rate: NameCallStyle.fadeRate))
            .offset(x: offset(size))
        }
        // **Pinned to the trip and cut at its edges.**
        //
        // The plate travels off both sides, so its own width is nothing anybody should be
        // laid out against — and every scene that uses it stacks it over the top of
        // something. A ZStack takes the width of its widest child, so an over-wide plate
        // re-centred the shot's backboard from a layer that is meant to be scenery.
        .frame(width: reach, height: size.height, alignment: .leading)
        .clipped()
        .allowsHitTesting(false)
        .task {
            withAnimation(.easeOut(duration: NameCallStyle.arrival)) { stage = .held }
        }
        .task(id: isLeaving) { await leave() }
    }

    /// What is left of it, given how long it has been going. One over `rate` seconds from
    /// full to nothing; full until it leaves.
    private func burn(at now: Date, rate: Double) -> Double {
        guard let leftAt else { return 1 }
        return max(0, 1 - now.timeIntervalSince(leftAt) * rate)
    }

    /// The word is the message and the shape is the envelope, so the word goes first.
    private var wordRate: Double {
        NameCallStyle.fadeRate * NameCallStyle.wordHaste
    }

    private var face: some View {
        // The seat's own colour, because the plate exists to say whose moment it is.
        Parallelogram(lean: ModeCardStyle.lean)
            .fill(NameCallStyle.taper(for: call.seat))
    }

    /// The name, in the one treatment names are drawn in — see `PlayerNameText` — over a
    /// note if there is one.
    ///
    /// Stretched horizontally only. A name is a word rather than a picture, and squashing
    /// it both ways to make it fit makes it *smaller* where what is wanted is *narrower*.
    private func word(burning left: Double) -> some View {
        HStack(spacing: NameCallStyle.gap) {
            PlayerNameText(seat: call.seat, size: NameCallStyle.labelSize)
            if let note = call.note {
                SmallCapsText(text: note, font: Chrome.display,
                              size: NameCallStyle.noteSize,
                              tracking: NameCallStyle.noteSize * 0.06)
                    .foregroundStyle(CardPalette.gray)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .scaleEffect(x: NameCallStyle.labelStretch, y: 1, anchor: .leading)
        .offset(x: NameCallStyle.labelX)
        .opacity(left)
    }


    private func offset(_ size: CGSize) -> CGFloat {
        switch stage {
        case .held:     reach - size.width
        case .offstage: -size.width
        // Far enough that the shape itself is gone, though the fade finishes long before.
        case .leaving:  reach + size.width
        }
    }

    private func leave() async {
        guard isLeaving, leftAt == nil else { return }
        leftAt = .now
        // **Linear, not eased in.** Easing in spends the first stretch barely moving, and
        // the first stretch is the only part anyone sees — it appeared to stall and vanish,
        // then do its travelling invisibly.
        withAnimation(.linear(duration: NameCallStyle.departure)) { stage = .leaving }
        try? await Task.sleep(for: .seconds(NameCallStyle.departure))
        onFinished()
    }
}

/// The plate's proportions and pacing.
@MainActor
enum NameCallStyle {
    /// How tall it is and how long, against how far it flies. Exactly the trip: the plate
    /// spans the screen and no more.
    static let height: CGFloat = 0.16
    static let length: CGFloat = 1.0

    /// Where the tail dissolves, as shares of the plate's own length.
    ///
    /// **Its own numbers, not the mother shape's.** Hers are shares of a bar 2.22× as long
    /// as its reach, so the ramp lands off the side of the screen; measured against a plate
    /// exactly as long as the trip, the same shares put a third of the screen in clear air
    /// with the name standing on it. A short dissolve at the tail is what she looks like
    /// from here.

    static func size(reaching reach: CGFloat) -> CGSize {
        CGSize(width: reach * length, height: reach * height)
    }

    static let fadeFrom: CGFloat = 0
    static let fadeTo: CGFloat = 0.06

    /// Solid at the front, gone at the tail — the mother shape's taper, on the end that
    /// trails as it flies out.
    static func taper(for seat: Seat) -> LinearGradient {
        let face = Theme.color(for: seat).opacity(ModeCardStyle.faceOpacity)
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: fadeFrom),
                .init(color: face, location: fadeTo),
                .init(color: face, location: 1),
            ]),
            startPoint: .leading, endPoint: .trailing)
    }

    static let labelSize: CGFloat = 22
    static let noteSize: CGFloat = 13
    static let gap: CGFloat = 8
    static let labelStretch: CGFloat = 0.85
    /// How far in from the **screen's** leading edge the name sits, in points. Measured
    /// from there rather than from the plate, which starts well off the side of it.
    static let labelX: CGFloat = 20

    /// In, read, out. **One way out, whatever else arrives** — an exit that can be
    /// interrupted looks like a mistake, and letting it run looks like two things having
    /// happened, which is what did.
    static let arrival: Double = 0.20
    /// How *fast* it goes on the way out, not how long it is seen for. The fade decides
    /// that, and the two are separate on purpose.
    static let departure: Double = 0.40

    /// How much opacity it loses per second on the way out. A **rate**, not a duration,
    /// and nothing animates it — see the note in `body`.
    static let fadeRate: Double = 4
    /// How much faster the word goes than the plate. Once the name has been read there is
    /// no reason to keep showing it over the scene.
    static let wordHaste: Double = 2.8
}

#if DEBUG
#Preview("Name call") {
    ZStack(alignment: .top) {
        Theme.courtFloor.ignoresSafeArea()
        NameCallView(call: NameCall(seat: .east, note: "at the line"), reach: 390)
            .padding(.top, 60)
    }
}
#endif
