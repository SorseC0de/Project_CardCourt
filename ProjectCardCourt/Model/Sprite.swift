import Foundation
import CoreGraphics

// Moved out of View/SpriteAnimation.swift. **How long a sheet is, and how big,**
// is a fact about the drawing that the rules and the timings both have to know —
// every duration in the game is `frames / rate`, so the frame table is upstream of
// the clock. `var face` stays behind with the view: it is the only member that
// needs `Kit`, and how a sheet wears a face is not a fact about the sheet's length.

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
    /// The three the referee holds rather than plays. He jogs the look-around loop while
    /// the game runs and stands in one of these the rest of the time — see `RefereeFigure`.
    case refereeRight = "Referee_Right"
    case refereeCall = "Referee_Call"
    case refereeShot = "Referee_Shot"
    /// Throwing it back in from the sideline. Four frames, and deliberately slow.
    case inbounder = "Player_Inbounder"
    /// What three of the four do during an inbound: turned upcourt toward the thrower.
    case inboundReceiverBack = "Player_Inbound_Receiver_Back"

    /// Dust off the floor. Five cells, and the last of them is deliberately empty — the
    /// puff ends on nothing rather than on a shape being switched off.
    case smoke = "Smoke"

    /// Guarding, and the swipe he makes on a Clamp that does its work at once.
    case defender = "Defender"
    case defenderSwipe = "Defender_Swipe"
    case shoot = "Player_Shoot"
    case sparkleBurst = "SparkleBurst"
    /// Two more of them, so three finishes at the rim do not all throw
    /// the same light — see `DunkStyle.Trip.burst`.
    case sparkleBurst2 = "SparkleBurst2"
    case sparkleBurst3 = "SparkleBurst3"
    /// A player facing the camera. One frame — a pose, not a loop.
    case front = "Player_front"
    /// Stood there with it, facing the room. What a man looks like holding a ball, as
    /// opposed to winding up to throw one in — see `Sprite.inbounder`.
    case holdBall = "Player_holdball"
    /// Turned away, watching the play. One frame, like `front` — it is what everybody who
    /// is not going up for the board is doing while somebody else is.
    case back = "Player_back"
    /// Side on. One frame, and the left is this one mirrored — the three views plus the
    /// back are the whole turn. See `Kit.Pose.stand`.
    case right = "Player_right"
    /// Squared up and glowering, arms out. Faceless like the rest of the turn, so the
    /// chosen face drops straight on it.
    case akuma = "Player_akumapose"
    /// Idling with the ball, face-on. Both carry their own ball, so nothing is laid over
    /// them — unlike the throw-in stance, which is drawn empty-handed.
    case spinBall = "Player_front_spinball"
    case bounceBall = "Player_front_bounceball"
    /// Arms out, taking it in; and the follow-through held after a jumper. Both one cell,
    /// both face-on — poses rather than loops, like `front`.
    /// Going up for the board, and coming down off it. Five cells up — he leaves the
    /// floor on the first and has both hands over his head on the last — and three back
    /// on to it. Neither loops: a jump happens once.
    case rebound = "Player_rebound"
    case land = "Player_land"
    /// Coming down with his back to you, which is how he comes down everywhere but off a
    /// board — a rebound turns him round to face the room and keeps `land`.
    case landBack = "Player_land_back"

    /// **The rim.** Two cells of gathering, then one of three finishes. They share the
    /// wind-up and part company after it: see `Dunk`, which says how each one climbs.
    case dunkPrepare = "Player_dunk_prepare"
    case dunkOneHand = "Player_dunk_1hand"
    case dunkReverse = "Player_dunk_reverse"
    case dunkWhirlwind = "Player_dunk_whirlwind"
    case praised = "Player_praised"
    case gooseneck = "Player_gooseneck"
    /// Nine heads and nine faces on 8-pixel strips, worn rather than played: the frame is
    /// picked, not advanced. A face is laid over a head, and both over a body — see
    /// `SpriteMetrics.headOrigin` for where they sit.
    case heads = "Player_heads"
    case faces = "Player_Faces"

    var frames: Int {
        switch self {
        case .shoot:        return 13
        case .sparkleBurst: return 14
        // Counted off the sheets, which are not the same length as each other.
        case .sparkleBurst2: return 18
        case .sparkleBurst3: return 17
        case .front, .back, .right, .akuma, .praised, .gooseneck, .holdBall: return 1
        case .refereeRight, .refereeCall, .refereeShot: return 1
        case .heads, .faces: return 9
        case .inbounder:    return 4
        // Three ways of standing about waiting for a throw.
        case .inboundReceiverBack: return 3
        case .rebound:      return 5
        case .land, .landBack: return 3
        case .dunkPrepare:  return 2
        case .dunkOneHand, .dunkReverse: return 5
        // Nine, counted off the sheet: five going up — he is at the rim on the last of
        // them — and four finishing. It is the long one, which is why it is the only
        // finish whose climb is its own animation rather than a held cell.
        case .dunkWhirlwind: return 9
        case .smoke:        return 5
        case .spinBall:     return 4
        case .bounceBall:   return 6
        case .defender:     return 2
        case .defenderSwipe: return 1
        default:            return 16
        }
    }


    /// Where this sheet's head sits on a given frame, in art pixels against the one on
    /// `Player_front`.
    ///
    /// The two ball sheets are drawn a pixel to the right of it, and the bounce lifts him
    /// a pixel for the second half of the toss — so whatever is laid on his face has to
    /// move with him rather than sitting where the still pose left it.
    ///
    /// **The floor of the eye table, not the whole of it.** `MarkTuning` starts from this
    /// and anything hand-placed overrides it.
    func headShift(atFrame frame: Int) -> CGPoint {
        switch self {
        case .spinBall:   return CGPoint(x: 1, y: 0)
        case .bounceBall: return CGPoint(x: 1, y: frame >= 3 ? -1 : 0)
        // Head thrown back a pixel with the arms out.
        case .praised:    return CGPoint(x: 0, y: -1)
        default:          return .zero
        }
    }

    /// Where an 8×8 head sits on this sheet, in art pixels from the cell's top-left.
    /// Measured off `Player_front` and shared by every 32-frame; the shot is drawn in a
    /// bigger frame and sits lower in it.
    var headOrigin: CGPoint {
        switch self {
        case .shoot: return CGPoint(x: SpriteMetrics.headOrigin.x + 8,
                                    y: SpriteMetrics.headOrigin.y + 8)
        default:     return SpriteMetrics.headOrigin
        }
    }

    /// Empty rows under the character, in art pixels. **Measured, one sheet at a time.**
    /// The 32-frames leave four; the shot is drawn in a 48-frame and leaves thirteen, so
    /// bottom-aligning the two put one man's feet nine pixels below the other's.
    var footPadding: CGFloat {
        switch self {
        case .shoot: return 13
        default:     return 4
        }
    }

    /// Source frame size. Everything scales off this, so the art stays on whole pixels.
    var frameSize: CGFloat {
        switch self {
        case .shoot:        return 48
        case .sparkleBurst, .sparkleBurst2, .sparkleBurst3: return 64
        case .heads, .faces: return 8
        default:            return 32
        }
    }
}

/// Measured rather than guessed: `Player_front`'s ink starts on row 5 of its 32-pixel
/// frame, and an 8-wide head centres at column 12. A head placed there lands exactly on
/// the body's shoulders, and the faces sheet is already aligned to the heads.
enum SpriteMetrics {
    static let headOrigin = CGPoint(x: 12, y: 5)
}
