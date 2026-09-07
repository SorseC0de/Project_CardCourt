import SwiftUI

/// A Swisshbone payout, the way the end of a match hands one over.
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
    /// When the burst started, so it plays once and is gone. A one-shot holds its last
    /// cell forever otherwise — which is how sparkles get left stuck on a screen.
    @State private var sparkedAt: Date?
    /// Drives the shine down the bone. One long linear repeat rather than a timer: the
    /// strip spends most of its travel off the metal, and that gap **is** the wait.
    @State private var sweeping = false

    private var pop: Animation { .spring(response: 0.42, dampingFraction: 0.52) }

    /// A band of light walking down the metal.
    ///
    /// **Clipped to the bone, not to a box.** The gradient is a wide angled strip, and
    /// masking it with the drawing is what makes the light look like it is on the object
    /// rather than passing in front of it. Screened rather than added: a highlight that
    /// blows out to white stops reading as a surface.
    private var shine: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .white.opacity(0.85), location: 0.5),
            .init(color: .clear, location: 1),
        ], startPoint: .top, endPoint: .bottom)
            .frame(width: side * 2.4, height: side * 0.38)
            .rotationEffect(.degrees(-30))
            // Well past the bone at both ends, so the strip is off it for most of the
            // trip — which is the pause between passes, without a second animation.
            .offset(y: sweeping ? side * 1.6 : -side * 1.6)
            .frame(width: side, height: side)
            .mask {
                Image(bone.asset)
                    .resizable().scaledToFit()
                    .frame(width: side, height: side)
            }
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    var body: some View {
        HStack(spacing: side * 0.18) {
            ZStack {
                Circle()
                    .fill(bone.glow.opacity(0.38))
                    .frame(width: side * 1.15, height: side * 1.15)
                    .blur(radius: side * 0.30)
                Circle()
                    .fill(bone.glow.opacity(0.22))
                    .frame(width: side * 0.8, height: side * 0.8)
                    .blur(radius: side * 0.16)
                // **One pass per blend.** Crystal is not painted on the dark, it is lit
                // through — and one pass of a soft blend barely registers, so it is laid
                // over itself. Two *different* ones stack differently again: the second
                // works on what the first left rather than on the ground. See `Bone.blends`.
                ForEach(Array((blends ?? bone.blends).enumerated()), id: \.offset) { pass in
                    Image(bone.asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: side, height: side)
                        .blendMode(pass.element)
                }
                if bone.shines { shine }
                // **Gold sparkles.** Over the bone rather than behind it: the burst is
                // light coming off the thing, and light behind it is a halo, which the
                // glow already is.
                if bone.sparkles, let sparkedAt {
                    SpriteAnimation(sprite: .sparkleBurst,
                                    scale: side / Sprite.sparkleBurst.frameSize * 1.4,
                                    fps: Theme.Figure.playerFPS,
                                    playsOnce: true, startedAt: sparkedAt)
                        .allowsHitTesting(false)
                }
            }
            Text("+\(amount)")
                .font(.system(size: side * 0.72, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: bone.glow.opacity(0.5), radius: side * 0.10)
                .shadow(color: Chrome.shade, radius: 0, x: side * 0.05, y: side * 0.05)
        }
        .scaleEffect(landed ? 1 : 0.25)
        .opacity(landed ? 1 : 0)
        .onChange(of: arrived, initial: true) { _, here in
            guard here else { landed = false; sparkedAt = nil; return }
            withAnimation(pop) { landed = true }
            if bone.shines, !sweeping {
                withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                    sweeping = true
                }
            }
            guard bone.sparkles else { return }
            sparkedAt = Date()
            // Cleared when the sheet has run, so nothing is left on the last cell.
            Task {
                let run = Double(Sprite.sparkleBurst.frames) / Theme.Figure.playerFPS
                try? await Task.sleep(for: .seconds(run))
                sparkedAt = nil
            }
        }
    }
}

/// The strips a Swisshbone comes in. One drawing, four ramps — see `Tools/bones`, which
/// writes the assets from the palette indices.
enum Bone: String, CaseIterable, Identifiable {
    case plain, gold, goldAlt, crystal

    var id: String { rawValue }

    var asset: String {
        switch self {
        case .plain:   return "Swisshbone"
        case .gold:    return "SwisshboneGold"
        case .goldAlt: return "SwisshboneGoldAlt"
        case .crystal: return "SwisshboneCrystal"
        }
    }

    var label: String {
        switch self {
        case .plain:   return "bone"
        case .gold:    return "gold"
        case .goldAlt: return "gold alt"
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
        self == .crystal ? [.softLight, .screen] : [.normal]
    }

    /// Whether it throws light off itself. Gold does; a plain bone is a plain bone.
    var sparkles: Bool { self == .gold || self == .goldAlt }

    /// Whether a band of light walks down it now and then. Metal catches the room; bone
    /// and glass do not, or not this way.
    var shines: Bool { self == .gold || self == .goldAlt }

    /// What it lights the dark behind it with. The plain one is white; the rest borrow
    /// the lightest entry of their own ramp, so the glow is the bone's own colour rather
    /// than a second one laid over it.
    var glow: Color {
        switch self {
        case .plain:   return .white
        case .gold:    return PixelPalette.gold
        case .goldAlt: return PixelPalette.khaki
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
