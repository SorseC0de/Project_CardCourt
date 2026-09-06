import SwiftUI

/// One of the player animations, sliced out of its vertical strip.
enum Sprite: String, CaseIterable {
    case catchBall = "Player_Catch"
    case dribble = "Player_Dribble"
    case run = "Player_Run"
    case runLook = "Player_Run_Look"
    /// The same glance over the other shoulder. North gets both and tosses for it — see
    /// `SpriteAnimation.current(at:)`.
    case runLook2 = "Player_Run_Look2"
    /// A wave at somebody off court, played now and then in place of a glance. Rare on
    /// purpose: it is a flourish, and a flourish on a timer stops being one.
    case wave = "Player_Wave"
    /// The referee's own sheet. He jogs and looks about like everyone else — a referee
    /// standing dead still would read as a prop rather than a man watching you.
    case refereeRunLook = "Referee_Run_Look"
    /// Throwing it back in from the sideline. Four frames, and deliberately slow.
    case inbounder = "Player_Inbounder"
    /// Waiting for it. One frame — nobody is moving during an inbound.
    case inboundReceiver = "Player_Inbound_Receiver"
    /// The same, seen from behind: what three of the four are during an inbound, since
    /// they are turned upcourt toward the thrower.
    case inboundReceiverBack = "Player_Inbound_Receiver_Back"

    /// Guarding, and the swipe he makes on a Clamp that does its work at once.
    case defender = "Defender"
    case defenderSwipe = "Defender_Swipe"
    case shoot = "Player_Shoot"
    case sparkleBurst = "SparkleBurst"
    /// A player facing the camera. One frame — a pose, not a loop.
    case front = "Player_front"
    /// Idling with the ball, face-on. Both carry their own ball, so nothing is laid over
    /// them — unlike the throw-in stance, which is drawn empty-handed.
    case spinBall = "Player_front_spinball"
    case bounceBall = "Player_front_bounceball"
    /// Nine heads and nine faces on 8-pixel strips, worn rather than played: the frame is
    /// picked, not advanced. A face is laid over a head, and both over a body — see
    /// `SpriteMetrics.headOrigin` for where they sit.
    case heads = "Player_heads"
    case faces = "Player_Faces"

    var frames: Int {
        switch self {
        case .shoot:        return 13
        case .sparkleBurst: return 14
        case .front:        return 1
        case .heads, .faces: return 9
        case .inbounder:    return 4
        case .inboundReceiver: return 1
        // Three ways of standing about waiting for a throw.
        case .inboundReceiverBack: return 3
        case .spinBall:     return 4
        case .bounceBall:   return 6
        case .defender:     return 2
        case .defenderSwipe: return 1
        default:            return 16
        }
    }

    /// Source frame size. Everything scales off this, so the art stays on whole pixels.
    var frameSize: CGFloat {
        switch self {
        case .shoot:        return 48
        case .sparkleBurst: return 64
        case .heads, .faces: return 8
        default:            return 32
        }
    }
}

/// Where the small sheets sit on the big ones.
///
/// Measured rather than guessed: `Player_front`'s ink starts on row 5 of its 32-pixel
/// frame, and an 8-wide head centres at column 12. A head placed there lands exactly on
/// the body's shoulders, and the faces sheet is already aligned to the heads.
enum SpriteMetrics {
    static let headOrigin = CGPoint(x: 12, y: 5)
}

/// Plays a strip by offsetting it a whole frame at a time behind a clip.
///
/// One `TimelineView` per sprite; the frame index is arithmetic off the clock rather than
/// stored state, so nothing accumulates drift and nothing is written per frame.
struct SpriteAnimation: View {
    let sprite: Sprite
    /// Art pixels per point. Whole numbers only — this is pixel art.
    var scale: CGFloat = 2
    var fps: Double = 10
    var isPlaying = true
    /// Held on this frame when not playing.
    var restFrame = 0
    /// Runs once and stops on the last frame, rather than looping.
    var playsOnce = false
    /// Cut to every so often for a single pass, then back. The base sprite keeps looping
    /// the rest of the time — an idle player never stops moving, they just glance about
    /// now and then.
    var alternate: Sprite?
    /// A second cut-away, when there is a choice of them. Tossed for each time one is due
    /// — off the cycle's own number, so it is settled rather than re-rolled every frame.
    var alternateOr: Sprite?
    /// A third, played instead of either of the others once in a while — see
    /// `Alternates.rarely` for how often, and `rolls` for why it is not simply random.
    var alternateRare: Sprite?
    var alternateEvery: TimeInterval = 5
    /// This sprite's own offset into the clock, so four players do not run — or glance —
    /// in unison.
    var phase: TimeInterval = 0
    /// When a one-shot started. Frames are counted from here.
    var startedAt: Date?
    /// Holds here instead of on the last frame, so a run can be cut short and kept —
    /// the shot-clock turnover plays the first of the catch and stops on the reach.
    var stopAtFrame: Int?

    private var side: CGFloat { sprite.frameSize * scale }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / fps, paused: !isPlaying)) { timeline in
            let showing = current(at: timeline.date)
            let index = isPlaying ? frame(of: showing, at: timeline.date) : restFrame
            Image(showing.rawValue)
                .interpolation(.none)
                .resizable()
                .frame(width: side, height: side * CGFloat(showing.frames))
                .offset(y: -CGFloat(index) * side)
                .frame(width: side, height: side, alignment: .top)
                .clipped()
        }
        .frame(width: side, height: side)
    }

    /// Which sheet is on screen right now.
    private func current(at date: Date) -> Sprite {
        guard let alternate else { return sprite }
        let clock = date.timeIntervalSinceReferenceDate + phase
        let run = Double(alternate.frames) / fps
        let cycle = clock.truncatingRemainder(dividingBy: alternateEvery)
        guard cycle < run else { return sprite }
        // Read off the number of the cycle rather than rolled: a random draw would land
        // differently on every frame of the same glance.
        let turn = Int(clock / alternateEvery)
        // Every so often he waves at somebody instead of checking his shoulder.
        if let alternateRare, Self.rolls(turn, oneIn: Alternates.rarely) { return alternateRare }
        guard let alternateOr else { return alternate }
        // Which shoulder, this time round.
        return turn.isMultiple(of: 2) ? alternate : alternateOr
    }

    enum Alternates {
        /// How often the rare one comes up, in glances.
        static let rarely = 7
    }

    /// A settled roll off the cycle's own number: the same cycle always answers the same
    /// way, so it holds for the whole of one glance — and consecutive cycles do not
    /// answer in a pattern, which a plain remainder would.
    static func rolls(_ turn: Int, oneIn odds: Int) -> Bool {
        var x = UInt64(bitPattern: Int64(turn)) &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 29
        return x % UInt64(odds) == 0
    }

    /// Which cell a looping sheet is on at this instant.
    ///
    /// A pure function of the wall clock, so anything laid over a sprite can ask the same
    /// question and get the same answer without the two having to share a view — see
    /// `HooperPortrait`, whose face has to move with a head that moves between frames.
    static func cell(of sprite: Sprite, at date: Date,
                     fps: Double, phase: TimeInterval = 0) -> Int {
        let elapsed = (date.timeIntervalSinceReferenceDate + phase) * fps
        return Int(elapsed.rounded(.down)) % sprite.frames
    }

    private func frame(of showing: Sprite, at date: Date) -> Int {
        guard playsOnce else {
            let elapsed = (date.timeIntervalSinceReferenceDate + phase) * fps
            return Int(elapsed.rounded(.down)) % showing.frames
        }
        guard let startedAt else { return 0 }
        let elapsed = date.timeIntervalSince(startedAt) * fps
        let last = min(stopAtFrame ?? showing.frames - 1, showing.frames - 1)
        return min(last, max(0, Int(elapsed.rounded(.down))))
    }
}


/// Something laid on a 32-pixel sheet, placed in the art's own coordinates.
///
/// Sprite overlays are all measured in art pixels — see `SpriteMetrics` — and a point
/// offset worked out from a centred frame is a number nobody can check against the
/// drawing. This takes the rectangle straight off the sheet.
struct OnSheet<Content: View>: View {
    /// Where it goes on the cell, in art pixels from its top-left.
    var rect: CGRect
    /// How far this frame's version of it has moved from that.
    var shift: CGPoint = .zero
    var scale: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 32 * scale, height: 32 * scale)
            content
                .frame(width: rect.width * scale, height: rect.height * scale)
                .offset(x: (rect.minX + shift.x) * scale,
                        y: (rect.minY + shift.y) * scale)
        }
    }
}
