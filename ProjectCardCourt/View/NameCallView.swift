import SwiftUI

// Ported from Project Stars, where the same shape announces that a passive fired. Kept
// whole for the same reason `ModeCardView` was: the movement is the part worth having.
// Only what it says is ours — there it names an effect, here it names a person.

/// Where the plate sits and where the name sits on it, while that is being eyeballed.
///
/// Five numbers, and every one of them has been wrong at least once: the plate's length
/// and where it comes to rest, and the name's size, width and inset. They are shares of
/// the trip rather than points, so a value read off the bench holds on any screen.
///
/// Freeze into `NameCallStyle` once they land.
@Observable
final class NameCallTuning {
    @MainActor static let shared = NameCallTuning()

    /// How long the plate is, against how far it flies.
    var cardWidth: CGFloat = NameCallStyle.length
    /// And how tall, against the same.
    var cardHeight: CGFloat = NameCallStyle.height
    /// Where its leading edge comes to rest, from the screen's own leading edge. Negative,
    /// so the tail runs off the side and the taper is seen against the screen's edge.
    var cardX: CGFloat = NameCallStyle.cardX
    /// How big the name is drawn, in points.
    var nameSize: CGFloat = NameCallStyle.labelSize
    /// Squeezed horizontally only — a name is a word, and squashing it both ways to make
    /// it fit makes it smaller where what is wanted is narrower.
    var nameWidth: CGFloat = NameCallStyle.labelStretch
    /// How far in from the plate's leading edge the name starts.
    var nameX: CGFloat = NameCallStyle.labelX
    /// Every stop in the taper, in order, as shares of the plate's length.
    ///
    /// Four of them when the fade is banded — clear, clear, face, face — and the middle
    /// two when it is one slope, since those are the only two a two-stop gradient has.
    /// All of them are dials: see `NameCallStyle.taper` for what the two shapes do
    /// differently.
    var stops: [CGFloat] = [0, NameCallStyle.fadeFrom, NameCallStyle.fadeTo, 1]
    /// One slope end to end instead of a ramp between two flats.
    var softTaper = NameCallStyle.softTaper
    /// How far south-east the plate's hard drop sits, in points.
    var drop: CGFloat = NameCallStyle.drop
    /// What colour that drop is — see `NameCallStyle.dropInk`.
    var dropInk: DropInk = NameCallStyle.dropInk

    /// The three the drop is being chosen between: white, or the seat's own colour taken
    /// a third and two thirds of the way to the palette's black.
    enum DropInk: String, CaseIterable, Identifiable, Codable {
        case white = "A", shaded = "B", darker = "C"
        var id: String { rawValue }
        var mix: Double? {
            switch self {
            case .white:  return nil
            case .shaded: return 0.33
            case .darker: return 0.66
            }
        }
    }
}

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
    @State private var tuning = NameCallTuning.shared

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
            // **Two children, both starting at the leading edge.** The port's own shape:
            // the plate, and the word over it at an offset. Nothing is negotiated between
            // them because the plate carries the frame and the word is `fixedSize`.
            ZStack(alignment: .leading) {
                face
                    // **A hard drop that thins out with the plate.**
                    //
                    // A shadow is drawn from what it is under — its alpha, tinted and
                    // offset — so a plate filled with a taper casts a tapered shadow
                    // without being told to. Radius nought keeps it a second edge rather
                    // than a glow, and it goes under the streaks so they are not doubled.
                    .shadow(color: NameCallStyle.dropInk(for: call.seat),
                            radius: 0, x: tuning.drop, y: tuning.drop)
                    .overlay { SideStreaks(ink: .white,
                                           thickness: StreakStyle.sideThicknessSmall)
                        .mask { face } }
                    .frame(width: size.width, height: size.height)

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
        // **Room below for the drop.** The clip is here so the plate cannot size anything
        // it is stacked over; cut to the plate's own height it also cut the southern half
        // of its shadow off, which left a drop that only went east.
        .frame(width: reach, height: size.height + tuning.drop, alignment: .topLeading)
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
            PlayerNameText(seat: call.seat, size: tuning.nameSize)
            if let note = call.note {
                SmallCapsText(text: note, font: Chrome.display,
                              size: NameCallStyle.noteSize,
                              tracking: NameCallStyle.noteSize * 0.06)
                    .foregroundStyle(CardPalette.gray)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .scaleEffect(x: tuning.nameWidth, y: 1, anchor: .leading)
        .offset(x: nameX)
        .opacity(left)
    }


    /// How far in the name sits.
    ///
    /// **Measured off the lean, because the lean is what pushes it off.** The plate is a
    /// parallelogram: its top-left corner is `height × lean` to the right of its
    /// bottom-left one, so at the height the word is drawn at, the shape's own edge is
    /// most of the way through that shift. A word placed at a flat inset from the frame
    /// hangs over the slanted edge on to nothing, which is exactly what it was doing.
    private var nameX: CGFloat { reach * tuning.nameX }

    private func offset(_ size: CGSize) -> CGFloat {
        switch stage {
        case .held:     reach * tuning.cardX
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
    static let height: CGFloat = 0.125
    static let length: CGFloat = 1.100

    /// Where the tail dissolves, as shares of the plate's own length.
    ///
    /// The mother shape's own ramp. It was cut to almost nothing while the plate was being
    /// placed, which took the taper off the left of the card altogether — with the plate
    /// three quarters of the trip and hung a quarter off the leading edge, this puts the
    /// dissolve across the first eighth of the screen, which is where it belongs.

    static func size(reaching reach: CGFloat) -> CGSize {
        CGSize(width: reach * NameCallTuning.shared.cardWidth,
               height: reach * NameCallTuning.shared.cardHeight)
    }

    /// One slope end to end, from here to here. Read off the bench, like the rest of the
    /// plate — see `NameCallTuning`, which is still where they can be moved.
    static let fadeFrom: CGFloat = 0.500
    static let fadeTo: CGFloat = 0.660
    /// Two stops rather than four: one continuous slope has no kink where a flat meets it.
    static let softTaper = true
    /// The seat's own colour, a third of the way to black.
    static let dropInk: NameCallTuning.DropInk = .shaded

    /// Solid at the front, gone at the tail — the mother shape's taper, on the end that
    /// trails as it flies out.
    /// **The transparent end is the face at zero, not `.clear`.**
    ///
    /// `.clear` is transparent *black*, and a gradient interpolates the colour as well as
    /// the alpha — so a ramp from `.clear` walks the hue down towards black on its way out
    /// and the tail reads as a dirty shadow rather than the plate thinning. The same colour
    /// at zero alpha only ever spends alpha, which is the fade that was wanted.
    ///
    /// ## Banded, or one slope
    ///
    /// The stop *count* is not what changes the picture — SwiftUI clamps outside the stop
    /// range, so flat/ramp/flat in four stops draws exactly what the same ramp draws in
    /// two. What changes it is where the ramp sits.
    ///
    /// **Banded** confines it between `fadeFrom` and `fadeTo`: flat, slope, flat. There is
    /// a kink at each end where flat meets slope, and the eye reads those as faint lines —
    /// and the whole alpha range is spent across a fifth of the width, so the steps are
    /// coarse enough to band.
    ///
    /// **Soft** runs one slope end to end: no kinks anywhere, and the same alpha change
    /// spread over five times the pixels.
    static func taper(for seat: Seat) -> LinearGradient {
        let face = Theme.color(for: seat).opacity(ModeCardStyle.faceOpacity)
        let tuning = NameCallTuning.shared
        // Sorted, because a gradient whose stops run backwards does not warn — it draws
        // something else.
        let at = tuning.stops.sorted()
        let stops: [Gradient.Stop] = tuning.softTaper
            ? [.init(color: face.opacity(0), location: at[1]),
               .init(color: face, location: at[2])]
            : [.init(color: face.opacity(0), location: at[0]),
               .init(color: face.opacity(0), location: at[1]),
               .init(color: face, location: at[2]),
               .init(color: face, location: at[3])]
        return LinearGradient(gradient: Gradient(stops: stops),
                              startPoint: .leading, endPoint: .trailing)
    }

    static let labelSize: CGFloat = 32
    static let noteSize: CGFloat = 13
    static let gap: CGFloat = 8
    static let labelStretch: CGFloat = 0.750
    /// Where the plate comes to rest and where the name sits on it, as shares of the trip.
    /// Read off the bench.
    static let cardX: CGFloat = -0.660
    static let labelX: CGFloat = 0.700
    /// The plate's own drop: hard and south-east. Whole points — a hard drop on a fraction
    /// of one is a blur.
    static let drop: CGFloat = 7

    /// What the drop is drawn in, for the seat the plate belongs to.
    static func dropInk(for seat: Seat) -> Color {
        guard let mix = NameCallTuning.shared.dropInk.mix else { return .white }
        return Theme.color(for: seat).mix(with: CardPalette.black, by: mix)
    }

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
/// The name plate with its five numbers on sliders — see `NameCallTuning`.
///
/// Its own struct rather than a bare `#Preview`, so `GameView.swift` can carry a preview
/// of it too. That file's canvas is the one that actually gets looked at.
struct NameCallBench: View {
    @State private var tuning = NameCallTuning.shared
    @State private var leaving = false
    @State private var seat: Seat = .east
    /// Bumped to build a fresh plate.
    ///
    /// `NameCallView` keeps the moment it began leaving and burns its opacity off from
    /// there, which is what makes the exit a rate rather than an animation — so lowering
    /// `isLeaving` again does not bring it back. Nothing does but a new one.
    @State private var run = UUID()

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Theme.courtFloor
                GeometryReader { geo in
                    NameCallView(call: NameCall(seat: seat), reach: geo.size.width,
                                 isLeaving: leaving)
                        .padding(.top, 40)
                        .id(run)
                }
                // The screen's own leading edge, to measure the name against.
                Rectangle().fill(CardPalette.red.opacity(0.6)).frame(width: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 170)

            VStack(spacing: 6) {
                dial("card width", $tuning.cardWidth, 0.2...2.5)
                dial("card height", $tuning.cardHeight, 0.04...0.5)
                dial("card x", $tuning.cardX, -1...1)
                dial("name size", $tuning.nameSize, 8...48)
                dial("name width", $tuning.nameWidth, 0.4...1.6)
                dial("name x", $tuning.nameX, -0.2...0.8)
                dial("drop", Binding(get: { tuning.drop },
                                     set: { tuning.drop = $0.rounded() }), 0...16)
                HStack(spacing: 14) {
                    Toggle("one slope end to end", isOn: $tuning.softTaper)
                        .font(.custom(Chrome.display, size: 15))
                        .foregroundStyle(.white)
                        .tint(CardPalette.gold)
                    // The drop's colour rides along here rather than taking a row of its
                    // own: A white, B and C the seat's colour a third and two thirds of
                    // the way to black.
                    Picker("", selection: $tuning.dropInk) {
                        ForEach(NameCallTuning.DropInk.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
                // Two stops or four, and a dial for every one of them. The two-stop shape
                // uses the middle pair, which are the only two it has.
                ForEach(tuning.softTaper ? [1, 2] : [0, 1, 2, 3], id: \.self) { index in
                    dial("stop \(tuning.softTaper ? index : index + 1)",
                         $tuning.stops[index], 0...1)
                }

                HStack(spacing: 12) {
                    Button("seat") { seat = seat.clockwise }
                    Button(leaving ? "return" : "leave") {
                        leaving.toggle()
                        // Coming back is a new plate: see `run`.
                        if !leaving { run = UUID() }
                    }
                    Button("reset") {
                        leaving = false
                        run = UUID()
                        tuning.cardWidth = NameCallStyle.length
                        tuning.cardHeight = NameCallStyle.height
                        tuning.cardX = NameCallStyle.cardX
                        tuning.nameSize = NameCallStyle.labelSize
                        tuning.nameWidth = NameCallStyle.labelStretch
                        tuning.nameX = NameCallStyle.labelX
                        tuning.stops = [0, NameCallStyle.fadeFrom, NameCallStyle.fadeTo, 1]
                        tuning.softTaper = NameCallStyle.softTaper
                        tuning.drop = NameCallStyle.drop
                        tuning.dropInk = NameCallStyle.dropInk
                    }
                }
                .font(.custom(Chrome.display, size: 15))
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CardPalette.black)
        }
        .ignoresSafeArea()
    }

    private func dial(_ name: String, _ value: Binding<CGFloat>,
                      _ range: ClosedRange<CGFloat>) -> some View {
        HStack(spacing: 10) {
            Text(String(format: "%@ %.3f", name, value.wrappedValue))
                .font(.custom(Chrome.display, size: 15))
                .foregroundStyle(.white)
                .frame(width: 150, alignment: .leading)
            Slider(value: value, in: range)
        }
    }
}

#Preview("Name call") { NameCallBench() }
#endif
