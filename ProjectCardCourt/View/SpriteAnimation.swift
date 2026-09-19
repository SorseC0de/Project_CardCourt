import SwiftUI

/// What a sheet wears on its face. The sheet itself — its length, its size, where a
/// head sits on it — is `Model/Sprite.swift`; this is the one member that needs a kit.
extension Sprite {
    /// **How this sheet wears the face, and where.** Nil is a sheet with no face to
    /// wear — the strips themselves, the referee who has his own, anything that is not a
    /// man seen from the front.
    ///
    /// Per sheet rather than per pose, because the court draws sheets the poses have no
    /// name for. See `Kit.FaceBuild` for what the three answers mean; audit them in
    /// `SpriteGallery`, which is what it is for.
    var face: Kit.FaceBuild? {
        switch self {
        // Drawn looking at you: both eyes, the sheet's one and its reflection.
        case .front, .spinBall, .bounceBall, .gooseneck, .praised, .holdBall:
            return .whole
        // Side on: the near eye, and the far one behind the nose.
        case .right:
            return .profile
        // The one finish that turns him back to the room on the way down.
        case .dunkReverse:
            return .whole
        // Glancing over a shoulder. His head is turned, so the eye nearer the edge of it
        // rides a pixel higher than the one still facing you.
        case .runLook, .runLook2, .wave:
            return .glancing(lift: -1)
        // Turned away, or not a man at all.
        default:
            return nil
        }
    }
}

/// Where the small sheets sit on the big ones.
///

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
    /// Turns the cut-away round, and only the cut-away — a referee who looks back over
    /// the other shoulder without his run being flipped.
    var mirrorsAlternate = false
    /// This sprite's own offset into the clock, so four players do not run — or glance —
    /// in unison.
    var phase: TimeInterval = 0
    /// When a one-shot started. Frames are counted from here.
    var startedAt: Date?
    /// Holds here instead of on the last frame, so a run can be cut short and kept —
    /// the shot-clock turnover plays the first of the catch and stops on the reach.
    var stopAtFrame: Int?
    /// The face this man wears, when he is a man who has one.
    ///
    /// **Composed here, not by the caller.** This view is the only thing that knows which
    /// sheet it settled on — a glance over either shoulder or a wave, picked off the wall
    /// clock — and which cell of it is up. A caller laying eyes on from outside has to
    /// guess both, so it did not: the floor drew every player faceless while the gallery
    /// and My Hooper, which hand `MarksOnSheet` a sheet and a cell directly, drew them
    /// correctly. Handed the sheet and the cell this view actually chose, they cannot
    /// disagree.
    var face: SpriteFace?

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
                .scaleEffect(x: mirrorsAlternate && showing != sprite ? -1 : 1)
                .overlay(alignment: .topLeading) {
                    if let face {
                        // Dressed by whoever is dressing the body: a figure on the floor
                        // wears one palette bundle for the strip, the trim and the skin.
                        MarksOnSheet(sheet: showing, face: face.index, tone: face.tone,
                                     scale: scale, number: face.number,
                                     numberInk: face.numberInk, frame: index,
                                     dressed: true, mirrored: face.mirrored)
                    }
                }
        }
        .frame(width: side, height: side)
        // **A sheet is taller than the cell it shows.** Sixteen frames is sixteen times
        // the height, offset upward to bring the right one into view — and `clipped()`
        // clips the drawing, not the touches. So every sprite was hit-testing a column
        // reaching thousands of points above itself, over whatever was up there. This
        // says the cell is the whole of it.
        .contentShape(Rectangle())
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
/// Everything a sheet needs to wear a face. Built once by `PlayerLook.faceOn(_:)`, so a
/// man's eyes, his skin and the number on his back are one answer rather than four.
struct SpriteFace: Equatable {
    /// Which of the nine off `Sprite.faces`.
    var index: Int
    var tone: Int
    /// Nil draws none — a sheet nobody has placed a number on, or a portrait.
    var number: String?
    var numberInk: Color = .white
    /// Whether the caller turns this figure around. **Digits are the one thing on him
    /// that must never mirror**: his kit, his face and where the number sits all read
    /// fine reversed, and a reversed 47 does not.
    var mirrored = false
}

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

extension Dunk {
    /// The sheet this finish is drawn from. **Here rather than on `Dunk` itself**: which
    /// dunk a man throws down is a rule, and which strip it is drawn from is not — the
    /// model does not know sprites exist.
    var sheet: Sprite {
        switch self {
        case .oneHand:   return .dunkOneHand
        case .reverse:   return .dunkReverse
        case .whirlwind: return .dunkWhirlwind
        }
    }
}
