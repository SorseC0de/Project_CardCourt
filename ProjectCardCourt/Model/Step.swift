import Foundation

/// **Something the play still owes.**
///
/// A play does not finish in one place. It sets some state, calls a few helpers, and
/// leaves the rest to be paid by whoever happens to run next — and for a long time
/// nothing enforced that anybody did. Five separate fields each held one owed thing, and
/// every bug of a certain shape was one of them going unpaid, being cleared before it was
/// paid, or being paid twice:
///
/// - Declining a counter returned early, so a Right Back's return leg stayed owed
///   forever. The ball sat with the receiver until the clock ran out — a shot-clock
///   violation with no visible cause.
/// - Fixing that exposed the opposite: the leg was cleared *before* the ball was sent
///   home, so the guard against a return asking for another return read nil and armed a
///   fresh trip every time.
/// - The forced shot was cleared unconditionally, so a chain that ended on a question
///   rather than on a possession dropped it on the floor and never re-armed it.
/// - Guarding that clear too tightly left it armed for the rest of the round, and it
///   fired on an unrelated possession later.
///
/// Owing something is pushing it now, and paying it is popping it. A step that cannot be
/// paid yet stays on the list, which is the whole of the fix: **the drain cannot finish
/// while a payable step remains**, and nothing else can clear one.
///
/// See `_Design/one-queue.md`, which is where this is going.
enum Step: Hashable, Codable {
    /// Free Agent: this hand goes to the pile once the chain that turned it up is done.
    /// Queued rather than dumped where it lands — turning the card up on the second card
    /// of an opening deal should cost the hand you end up with, not the one you had.
    case spendHand(Seat)
    /// Right Back: the ball owes a trip home, and the card paying for it. Queued to the
    /// chain's edge so whatever the outward leg cost him lands first.
    case returnBall(to: Seat, leg: CardDescriptor)
    /// Alley-Oop: the man it found owes a shot the instant the chain settles. A shot
    /// resolved mid-draw is a shot taken before the cards that were still arriving.
    case shootAtOnce(Seat)
    /// Benched, and any Whistle that hands the ball over: this man puts it back in play.
    /// Queued because a Game Break resolves from inside `beginPossession`, which sets the
    /// phase on its way out over whatever it finds there.
    case handOverBall(Seat)
    /// Awarded but not yet shot, for the same reason.
    case takeTheLine(FreeThrowTrip)
    /// **A Game Break turned up by a draw, waiting for the draw to finish.**
    ///
    /// A draw is one act however many cards it moves, and a Break that resolved the
    /// moment it came off the deck moved SHOT under the rest of the draws and asked
    /// about a full board before the card that filled it had arrived. It waits here,
    /// in the order it came off the deck — see `Rules.drainBreaks`.
    case revealBreak(PendingBreak)
    /// Frostbite Finish: a Move played, and the cards it costs still owed.
    case tax(seat: Seat, count: Int, card: CardDescriptor)
    /// Monster Ball, gone: the Intangibles it swallowed are rebounded for, one at a time.
    case intangibleBoards

    /// **Where this sits in a drain, which is not the order it was pushed in.**
    ///
    /// A hand going to the pile is paid before the ball moves, and a forced shot before
    /// the board asks whose passive goes, because each is the ground the next stands on.
    /// This is the order the five have always been paid in; the queue is what makes them
    /// one mechanism, not a reason to change what they do.
    var rank: Int {
        switch self {
        // A Break outranks everything: it can empty the hand the next step was going to
        // spend, take the ball off the man the next step was sending it to, and end the
        // round the next step was shooting in.
        case .revealBreak:  return -1
        case .spendHand:    return 0
        case .handOverBall: return 1
        case .returnBall:   return 2
        case .shootAtOnce:  return 3
        case .takeTheLine:  return 4
        case .tax:          return 0
        case .intangibleBoards: return 5
        }
    }

    /// What kind it is, without its contents — for saying which step went unpaid, and for
    /// dropping a kind when a break in the play outranks it.
    var kind: Kind {
        switch self {
        case .spendHand:    return .spendHand
        case .returnBall:   return .returnBall
        case .shootAtOnce:  return .shootAtOnce
        case .handOverBall: return .handOverBall
        case .takeTheLine:  return .takeTheLine
        case .revealBreak:  return .revealBreak
        case .tax:          return .tax
        case .intangibleBoards: return .intangibleBoards
        }
    }

    enum Kind: String, Hashable, Codable {
        case spendHand, returnBall, shootAtOnce, handOverBall, takeTheLine, revealBreak
        case tax, intangibleBoards
    }
}
