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
    static let ink          = Color(red: 0.93, green: 0.93, blue: 0.95)
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
        case .gameBreak:    return CardPalette.purple
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
        static let handY: CGFloat = 0.18

        /// How long the ball takes to cross.
        static let flightSeconds: Double = 0.26
        /// How long it stays in the receiver's hands before the sprite's own ball takes
        /// over.
        static let holdSeconds: Double = 0.08

        /// How long a catch takes, start to finish.
        ///
        /// **The only number to move.** The frame rate follows from it, and everything
        /// that has to stay in step — the hold, the sprite swap, a cutscene's ball flight
        /// — is measured from the same place, so speeding a catch up cannot leave one of
        /// them behind. It ran at 10 frames a second, which is 1.6 seconds of catching
        /// before a player would so much as start dribbling.
        static let catchSeconds: Double = 0.60
        static var catchFPS: Double { Double(Sprite.catchBall.frames) / catchSeconds }
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
        /// The sheets were exported at 10 (0.1s per frame in the GIFs); they read
        /// sluggish at that, so the game runs them faster than they were authored.
        static let playerFPS: Double = 15
        /// The sideline animations — the inbounder, the defender. Game & Watch slow: two
        /// poses and a hold, so the eye reads a state rather than a motion.
        static let sidelineFPS: Double = 4
        /// The shot runs slower than play does — it is the beat the scene is built on.
        static let shootFPS: Double = 8
        /// Empty rows under the character in the sheet: the ink ends four pixels short
        /// of the frame, which is dead space anything sitting below has to be pulled
        /// back through.
        static let spriteFootPadding: CGFloat = 4 / 32
        /// The sprite is square, so its footprint is just its side.
        static var height: CGFloat { Sprite.run.frameSize * playerScale }
    }
}
