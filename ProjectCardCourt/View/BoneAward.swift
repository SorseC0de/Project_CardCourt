import SwiftUI

/// A Swishbone payout, the way the end of a match hands one over.
///
/// **It arrives rather than appears.** The bone pops in on a spring loose enough to
/// overshoot, and the count lands with it — a reward that fades up reads as a number
/// going on a ledger, and this is meant to read as being handed something.
///
/// The glow is behind the bone and takes the strip's own colour, white for the plain one.
/// Kept dim on purpose: a blur under a view comes out far hotter than the same bloom does
/// on a canvas, and a bone lit like a lamp stops looking like an object.
struct BoneAward: View {
    var bone: Bone = .plain
    var amount: Int
    /// How big the bone is drawn; the count is sized against it.
    var side: CGFloat = 64
    /// Held off until this is true, so a screen can bring several in one after another.
    var arrived = true
    /// Overrides the strip's own passes, for trying them against each other on the bench.
    var blends: [BlendMode]?

    @State private var landed = false
    /// How many characters of the count have arrived.
    @State private var said = 0
    /// Seconds for one full trip round the hue wheel.
    static let breath: Double = 16

    /// How far off the vertical the bone hangs.
    static let lean: Double = -10

    /// The count, as a share of `side`. **The digits stand out and the sign does not** —
    /// an operator set at the digits' size is the mark of a menu rather than a scoreboard.
    /// The same rule is written down in `ModeCardView`.
    static let digitSize: CGFloat = 0.86
    static let signSize: CGFloat = 0.48
    /// The sign, lifted off the baseline the digits sit on and tucked into them.
    static let signLift: CGFloat = -0.16
    static let signTuck: CGFloat = 0.10

    private var pop: Animation { .spring(response: 0.42, dampingFraction: 0.52) }

    /// The light behind the bone. **Crystal has no colour of its own** — it is lit by
    /// whatever passes through it, so its halo walks the hue wheel and swells as it goes
    /// rather than sitting on one tint. Everything else takes the one colour and holds it,
    /// and the timeline is parked so it costs nothing.
    private var halo: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !bone.breathes)) { pass in
            let clock = pass.date.timeIntervalSinceReferenceDate / Self.breath
            let hue = clock - clock.rounded(.down)
            // Out of step with the hue, so the swell does not land on the same colour
            // every cycle — the two together are what reads as breathing.
            let swell = bone.breathes ? 0.78 + 0.22 * cos(clock * 2.6 * .pi) : 1
            let tint = bone.breathes
                     ? Color(hue: hue, saturation: 0.72, brightness: 1)
                     : bone.glow
            ZStack {
                Circle()
                    .fill(tint.opacity(0.38 * bone.bloom * swell))
                    .frame(width: side * 1.15, height: side * 1.15)
                    .blur(radius: side * 0.30)
                Circle()
                    .fill(tint.opacity(0.22 * bone.bloom * swell))
                    .frame(width: side * 0.8, height: side * 0.8)
                    .blur(radius: side * 0.16)
            }
        }
    }

    /// One character of the count: the game's own face, in the wordmark's two inks.
    ///
    /// **The mark's fill, not a flat one.** White above and `lightBlue` below, meeting at
    /// a line rather than blending — see `Chrome.hardSplit`, which reads the split against
    /// the cap band, so it is passed this glyph's own font rather than the row's.
    private func character(_ glyph: Character, shown: Bool) -> some View {
        let sign: Bool = glyph == "+"
        let digit: CGFloat = side * Self.digitSize
        let face: CGFloat = sign ? side * Self.signSize : digit
        // Keyed to the digits so the drop is one distance across the whole count rather
        // than shrinking with the sign.
        let drop: CGFloat = max(3, digit * 0.06)
        let lift: CGFloat = sign ? digit * Self.signLift : 0
        let tuck: CGFloat = sign ? -digit * Self.signTuck : 0
        let ink = LinearGradient.hardSplit(.white, CardPalette.lightBlue,
                                          in: UIFont(name: Chrome.display, size: face))
        return Text(String(glyph))
            .font(.custom(Chrome.display, size: face))
            .foregroundStyle(ink)
            .shadow(color: CardPalette.blue, radius: 0, x: drop, y: drop)
            .offset(y: lift)
            .padding(.trailing, tuck)
            .scaleEffect(shown ? 1 : 0.2)
            .opacity(shown ? 1 : 0)
    }

    var body: some View {
        HStack(spacing: side * 0.18) {
            ZStack {
                // Bone is the ordinary one and throws no light at all — see `Bone.bloom`.
                if bone.bloom > 0 { halo }
                // **One pass per blend.** Crystal is not painted on the dark, it is lit
                // through — and one pass of a soft blend barely registers, so it is laid
                // over itself. Two *different* ones stack differently again: the second
                // works on what the first left rather than on the ground. See `Bone.blends`.
                // **Tipped off the vertical.** Dead upright reads as an icon in a list;
                // a few degrees of lean makes it an object being handed over. The shine
                // leans with it, since its mask is the bone.
                Group {
                    ForEach(Array((blends ?? bone.blends).enumerated()), id: \.offset) { pass in
                        Image(bone.asset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: side, height: side)
                            .blendMode(pass.element)
                    }
                    if bone.shines { MetalShine(asset: bone.asset, side: side) }
                }
                .rotationEffect(.degrees(Self.lean))
                // **Gold twinkles.** Drawn, not a sheet: the bone is a vector with its
                // own shading, and a pixel-art burst over it reads as two different games
                // in one frame. They sit around it rather than behind — behind is where
                // the glow already is — and they carry on rather than playing once, since
                // metal keeps catching the light.
                if bone.sparkles {
                    // Gold's all catch the one colour; glass gives each its own.
                    BoneSparkles(side: side,
                                 tint: bone.breathes ? nil : bone.glow,
                                 wheel: Self.breath)
                }
            }
            // **The bone lands, then the number is spelled.** All of it at once is a
            // label appearing; one character at a time is a count being read out.
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array("+\(amount)".enumerated()), id: \.offset) { place, glyph in
                    character(glyph, shown: place < said)
                }
            }
        }
        .scaleEffect(landed ? 1 : 0.25)
        .opacity(landed ? 1 : 0)
        .onChange(of: arrived, initial: true) { _, here in
            guard here else { landed = false; said = 0; return }
            withAnimation(pop) { landed = true }
            Task {
                // A beat for the bone to arrive, then the characters, one at a time.
                try? await Task.sleep(for: .seconds(0.22))
                for step in 1..."+\(amount)".count {
                    withAnimation(pop) { said = step }
                    try? await Task.sleep(for: .seconds(0.11))
                }
            }
        }
    }
}

/// A band of light walking down a drawing now and then — a Swishbone's metal, and Brand
/// New Ball.
///
/// **Clipped to the drawing, not to a box.** The gradient is a wide angled strip, and
/// masking it with the drawing is what makes the light look like it is on the object
/// rather than passing in front of it. Screened rather than added: a highlight that
/// blows out to white stops reading as a surface.
struct MetalShine: View {
    let asset: String
    let side: CGFloat

    /// Drives the shine down it. One long linear repeat rather than a timer: the strip
    /// spends most of its travel off the drawing, and that gap **is** the wait.
    @State private var sweeping = false

    var body: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .white.opacity(0.85), location: 0.5),
            .init(color: .clear, location: 1),
        ], startPoint: .top, endPoint: .bottom)
            .frame(width: side * 2.4, height: side * 0.38)
            .rotationEffect(.degrees(-30))
            // Well past the drawing at both ends, so the strip is off it for most of the
            // trip — which is the pause between passes, without a second animation.
            .offset(y: sweeping ? side * 1.6 : -side * 1.6)
            .frame(width: side, height: side)
            .mask {
                Image(asset)
                    .resizable().scaledToFit()
                    .frame(width: side, height: side)
            }
            .blendMode(.screen)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                    sweeping = true
                }
            }
    }
}

/// The strips a Swishbone comes in. One drawing, four ramps — see `Tools/bones`, which
/// writes the assets from the palette indices.
enum Bone: String, CaseIterable, Identifiable {
    /// **Declared in the order they are worth**, because that is the order every screen
    /// walks them in — the bench, the preview, and whatever hands one over.
    case plain, bronze, silver, gold, crystal

    var id: String { rawValue }

    var asset: String {
        switch self {
        case .plain:   return "Swishbone"
        case .bronze:  return "SwishboneBronze"
        case .silver:  return "SwishboneSilver"
        case .gold:    return "SwishboneGold"
        case .crystal: return "SwishboneCrystal"
        }
    }

    var label: String {
        switch self {
        case .plain:   return "bone"
        case .bronze:  return "bronze"
        case .silver:  return "silver"
        case .gold:    return "gold"
        case .crystal: return "crystal"
        }
    }

    /// How it meets what is behind it, one entry per pass.
    ///
    /// **Crystal is the one that is not opaque.** Its colours lighten what they sit on
    /// rather than replacing it, which is what makes a thing read as glass rather than as
    /// a painted shape of glass — and it takes more than one pass, because the second
    /// works on what the first left rather than on the ground. Everything else is a single
    /// opaque pass.
    var blends: [BlendMode] {
        self == .crystal ? [.softLight, .softLight] : [.normal]
    }

    /// Whether it throws light off itself. **Gold catches the room and glass splits it.**
    /// The two below them do not: bronze and silver are working metals, and the sparkle is
    /// what separates a prize from a payment. Bone is bone.
    var sparkles: Bool { self == .gold || self == .crystal }

    /// Whether the glow cycles rather than holding one colour.
    var breathes: Bool { self == .crystal }

    /// Whether a band of light walks down it now and then. Metal catches the room; bone
    /// and glass do not, or not this way.
    var shines: Bool { self != .plain }

    /// How much light it throws. **Bone is not a precious thing** — a plain one lit like
    /// gold reads as the same reward in a different colour, when the whole point is that
    /// it is the ordinary one.
    var bloom: Double {
        switch self {
        case .plain:   return 0
        case .bronze:  return 0.75
        case .silver:  return 0.85
        default:       return 1
        }
    }

    /// What it lights the dark behind it with. The plain one is white; the rest borrow
    /// the lightest entry of their own ramp, so the glow is the bone's own colour rather
    /// than a second one laid over it.
    var glow: Color {
        switch self {
        case .plain:   return .white
        case .bronze:  return PixelPalette.khaki
        // The one whose own ramp has no colour in it — the highlight rather than the
        // metal, so the light off it reads as light and not as a grey lamp.
        case .silver:  return PixelPalette.ice
        case .gold:    return PixelPalette.gold
        case .crystal: return PixelPalette.aqua
        }
    }
}

#if DEBUG
#Preview("Payout") {
    ZStack {
        Chrome.ground.ignoresSafeArea()
        VStack(spacing: 24) {
            ForEach(Bone.allCases) { BoneAward(bone: $0, amount: 12) }
        }
    }
}
#endif
