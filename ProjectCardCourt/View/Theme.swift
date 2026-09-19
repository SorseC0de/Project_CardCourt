import SwiftUI

/// One place for every colour and metric the game draws with.
enum Theme {
    static let court        = Color(red: 0.72, green: 0.47, blue: 0.26)
    /// Opaque, so it hides the streaks behind it. Matches what the old translucent
    /// floor composited to, rather than quietly brightening the court.
    /// Sampled from the bottom of Swissh Court, so the drawn floor and the painted one
    /// are the same brown. Its background is a gradient running up from this into near
    /// black, and the corners clamp to the bottom stop — rgb(133, 97, 71).
    static let courtFloor   = Color(red: 133 / 255, green: 97 / 255, blue: 71 / 255)
    static let courtLine    = Color.white.opacity(0.28)
    /// The light that travels down the floor.
    static let courtSweep   = Color(red: 0.98, green: 0.72, blue: 0.35).opacity(0.22)
    /// How dark the screen goes behind each thing that takes it over. One place, because
    /// there is one dim doing all of it — see `GameView.dim`.
    static let dimWhistle: Double = 0.80
    static let dimReveal: Double = 0.72
    static let dimBrowser: Double = 0.85
    /// Behind a phase call. Lighter than the whistle's, because the call is a word rather
    /// than a card to be read.
    static let dimCall: Double = 0.66

    static let panel        = Color(red: 0.11, green: 0.12, blue: 0.15)
    static let panelRaised  = Color(red: 0.16, green: 0.17, blue: 0.21)
    /// True white. Every HUD, scoreboard and UI word is written in it.
    static let ink          = Color.white
    /// **The main scene's ground**: true black, under the status bar, the scoreboard and
    /// the court, which fades into it at the horizon.
    static let sceneGround  = Color.black
    static let inkDim       = Color(red: 0.58, green: 0.60, blue: 0.66)
    static let ball         = Color(red: 0.90, green: 0.45, blue: 0.13)
    static let live         = Color(red: 0.36, green: 0.85, blue: 0.52)
    static let danger       = Color(red: 0.94, green: 0.35, blue: 0.35)

    static let clockAmber = Color(red: 0.98, green: 0.76, blue: 0.20)
    static let clockOrange = Color(red: 0.95, green: 0.49, blue: 0.12)
    static let clockRed = Color(red: 0.91, green: 0.22, blue: 0.20)

    /// Shot clock warms from amber through orange to red as time runs out.
    static func clockColor(for value: Int?) -> Color {
        guard let value else { return inkDim }
        switch value {
        case ...2:  return clockRed
        case 3...6: return clockOrange
        default:    return clockAmber
        }
    }

    /// Card type colours, following the sheet's palette. Two departures: Clamps take
    /// red because Whistles are drawn striped instead, which frees orange for Special
    /// Move — the one type the sheet never gave a colour — and Intangibles are gold
    /// rather than the sheet's grey.
    static func color(for type: CardType) -> Color {
        switch type {
        case .pass:         return CardPalette.blue
        case .move:         return CardPalette.green
        case .specialMove:  return CardPalette.orange
        case .clamp:        return CardPalette.red
        case .whistle:      return Color(white: 0.94)
        case .gameBreak, .varena: return CardPalette.purple
        case .variaball:    return CardPalette.orange
        case .injury:       return CardPalette.gray
        case .intangible:   return CardPalette.gold
        }
    }

    /// Whistles are striped rather than a flat colour, matching the referee.
    static func isStriped(_ type: CardType) -> Bool { type == .whistle }

    /// Defenders a Clamp puts on the floor. Always red, whoever played it.
    static let defender = Color.red

    static func color(for seat: Seat) -> Color {
        switch seat {
        case .north: return Color(red: 0.96, green: 0.80, blue: 0.30)
        case .east:  return Color(red: 0.35, green: 0.78, blue: 0.62)
        case .south: return Color(red: 0.36, green: 0.60, blue: 0.94)
        case .west:  return Color(red: 0.61, green: 0.36, blue: 0.90)
        }
    }

    /// Where a pass lands in a player's hands, and how long it stays there.
    ///
    /// The position is in shares of a figure's own height rather than points, so one pair
    /// of numbers lands in the same place on every seat, whatever their scale or where
    /// they stand. Dialled in on the bench and frozen here.
    enum Pass {
        /// Out from the middle of the player's feet. Negative sits it on their far side.
        static let handX: CGFloat = -0.14
        /// Up from them.
        static let handY: CGFloat = 0.23

        /// Where the ball meets him at the top of a rebound: his hands come together
        /// over his head on the sheet's last cell, twenty-six pixels up in a thirty-two
        /// pixel frame, and the leap's own lift puts him two higher again.
        static let reboundHandX: CGFloat = 0
        static let reboundHandY: CGFloat = 28.0 / 32

        // The three durations a pass is *paced* by live in `PassTiming`, where the
        // engine can read them without importing SwiftUI. Forwarded here so every view
        // that already spells them this way is untouched.
        static var flightSeconds: Double { PassTiming.flight }
        static var holdSeconds: Double { PassTiming.hold }
        static var catchFPS: Double { PassTiming.catchFPS }
        static var catchSeconds: Double { PassTiming.catchSeconds }
    }

    enum Figure {
        /// Wider than the body. Looking down at someone, the head is the widest thing.
        static let headDiameter: CGFloat = 32
        /// Squat: wider than it is tall, which is what a body looks like from above.
        static let bodyWidth: CGFloat = 28
        static let bodyHeight: CGFloat = 26
        /// Negative — the head sits down into the shoulders. That overlap is what reads
        /// as looking down at the player rather than straight at them.
        static let gap: CGFloat = -9
        /// Art pixels per point. Whole numbers only — this is pixel art.
        /// The sprite fills only about 40% of its frame's width, so a good deal of what
        /// this multiplies is padding — the visible player is far smaller than the number.
        static let playerScale: CGFloat = 8
        /// What a player nobody may choose is worth, while somebody is being chosen.
        /// Low: at four tenths a man who is not an option still reads as a man standing
        /// there, and the whole point is that he is not one of the answers.
        static let dimmed: Double = 0.15
        // ── How fast the sheets play ────────────────────────────────────
        //
        // **The rate is chosen and the duration follows.** A sheet plays at a speed
        // somebody picked for the drawing, and how long it takes is `frames / rate`.
        // Never the reverse: pick a duration and the rate that falls out is whatever
        // arithmetic left behind.
        //
        // **The test is refreshes, not round numbers.** A screen redraws sixty times a
        // second — a hundred and twenty on the newer ones — so a rate is even only if
        // `60 / rate` is a whole number of them. At 7.5 every cell is held for exactly
        // eight refreshes and reads clean; at 8 it alternates seven and eight and
        // judders. These are the rates that pass, and nothing plays at anything else:
        //
        //     4 → 15    7.5 → 8    10 → 6    12 → 5    15 → 4    20 → 3    30 → 2
        //
        // Sprite sheets only. A card's hold or a ball's arc is arithmetic rather than
        // animation and takes whatever it needs.

        /// The sheets were exported at 10 (0.1s per frame in the GIFs); they read
        /// sluggish at that, so the game runs them faster than they were authored.
        static let playerFPS: Double = 15
        /// The sideline animations — the inbounder, the defender. Game & Watch slow: two
        /// poses and a hold, so the eye reads a state rather than a motion.
        static let sidelineFPS: Double = 4
        /// The shot runs slower than play does — it is the beat the scene is built on.
        /// Was 8, which is the one rate in the game that did not divide the refresh.
        static let shootFPS: Double = 10
        /// A Lethal Shooter's shot, a step quicker: the next rate that divides the refresh.
        static let lethalShootFPS: Double = 12

        // ── Going up for the board ──────────────────────────────────────
        /// Which cell of the rise the extra height comes in on. He reaches the top of the
        /// sheet on the way up and the jump wants to be higher than the sheet is tall,
        /// but not from the first frame — those are him leaving the floor, which the
        /// drawing already says.
        ///
        /// **The only one of these left.** Every other number in the leap — both rates,
        /// the hang, the drop, how high he goes — lives on `ReboundTuning`, where it can
        /// be moved against the others and watched. A second set here was a second answer
        /// to the same question, and nothing read it.
        static let reboundLiftFrom = 3

        /// What a shadow does while its owner is off the floor: how much of its size and
        /// how much of its opacity are left at the top. It does not follow him up — it
        /// shrinks and thins as the gap opens.
        static let shadowInAir: CGFloat = 0.62
        static let shadowFadeInAir: CGFloat = 0.5
        /// The turn on the My Hooper stage: half a second a view, two seconds all the way
        /// round. Two divides sixty like every other rate in the game.
        static let turnFPS: Double = 2
        /// Standing about with the ball. Slow on purpose — a spin or a bounce at the
        /// running rate reads as fidgeting rather than as somebody waiting.
        static let idleBallFPS: Double = 7.5
        /// Empty rows under the character in the sheet: the ink ends four pixels short
        /// of the frame, which is dead space anything sitting below has to be pulled
        /// back through.
        static let spriteFootPadding: CGFloat = 4 / 32

        // ── Dust ────────────────────────────────────────────────────────
        // The numbers are `SmokeStyle`'s, and the live ones `SmokeTuning`'s. They were
        // here, which meant a dial and a default in two files disagreeing about which was
        // the fact — see `SmokePuff`.
        /// The sprite is square, so its footprint is just its side.
        static var height: CGFloat { Sprite.run.frameSize * playerScale }
    }
}
