import SwiftUI

// MARK: - What a lesson is made of

/// Something on the game screen a lesson can point at.
enum TutorialTarget: Hashable {
    /// A card in the player's hand, by what it is.
    case handCard(String)
    /// The SHOT figure at the foot of that card.
    case cardBadge(String)
    /// The SHOT readout at the top of the court.
    case shotHUD
    /// Where the way out is drawn: under the log, in the corner the Varena takes in a game.
    case exitSpot
}

/// What moves a step on.
enum TutorialAdvance: Equatable {
    /// A tap anywhere.
    case tap
    /// The player plays this many cards, and the table has finished showing them.
    case plays(Int)
    /// The ball leaves the player.
    case pass
}

struct TutorialStep {
    var text: String
    /// Left out of the wash.
    var focus: [TutorialTarget] = []
    /// Drawn bigger while the step is up.
    var enlarged: Set<TutorialTarget> = []
    var advance: TutorialAdvance = .tap
    /// The ball crosses in slow motion, with the screen zoomed in on it.
    var slowMotion = false
}

/// One stretch of a lesson. A blip on the popover.
struct TutorialLeg {
    var title: String
    /// The hand the leg starts from. Nil carries on from wherever the last leg left off.
    var hand: [CardDescriptor]?
    /// What the next draws turn up, first draw first.
    var deckTop: [CardDescriptor] = []
    var steps: [TutorialStep]
}

struct Tutorial: Identifiable {
    let id: String
    let title: String
    /// The card type it teaches, as its cards are named.
    let cardName: String
    /// And as they are printed, which the popovers and the menu button are printed in too.
    let face: CardFace
    let legs: [TutorialLeg]
    /// Said when the last step is done.
    let farewell: String

    /// A card of this type with nothing on it but its icon, and a name if given one.
    func blankCard(named name: String = "") -> CardDescriptor {
        CardDescriptor(id: "blank-\(id)", name: name, type: face.type, effect: "",
                       numberInDeck: 0)
    }
}

// MARK: - Running one

/// **Walks a lesson over a real table.** It stages each leg's hand on the controller, says
/// what the current step says, and moves on on a tap or once the player has done the thing.
@Observable
@MainActor
final class TutorialDirector {
    let tutorial: Tutorial
    let controller: GameController
    private(set) var leg = 0
    private(set) var step = 0
    private(set) var isFinished = false
    private(set) var hasStarted = false
    private var playsAtStepStart = 0

    init(tutorial: Tutorial, controller: GameController) {
        self.tutorial = tutorial
        self.controller = controller
    }

    var current: TutorialStep? {
        guard !isFinished, hasStarted else { return nil }
        return tutorial.legs[leg].steps[step]
    }

    /// What the table lifts out of the wash and draws bigger.
    var focus: TutorialFocus {
        TutorialFocus(targets: Set(current?.focus ?? []), enlarged: current?.enlarged ?? [])
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        stage(leg: 0)
    }

    /// A tap on the lesson. Only a step that waits for one takes it.
    func tapped() {
        guard current?.advance == .tap else { return }
        next()
    }

    /// The table moved on; a step waiting on the player may be done.
    func gameMoved() {
        guard let current else { return }
        switch current.advance {
        case .tap:
            return
        case .plays(let count):
            guard controller.lessonPlays - playsAtStepStart >= count,
                  case .awaitingMove = controller.gate else { return }
            next()
        case .pass:
            guard controller.lessonBallGone else { return }
            next()
        }
    }

    private func stage(leg index: Int) {
        leg = index
        step = 0
        let plan = tutorial.legs[index]
        controller.stageLesson(hand: plan.hand, deckTop: plan.deckTop)
        stepBegan()
    }

    private func next() {
        if step + 1 < tutorial.legs[leg].steps.count {
            step += 1
            stepBegan()
        } else if leg + 1 < tutorial.legs.count {
            stage(leg: leg + 1)
        } else {
            isFinished = true
            controller.setLessonSlowMotion(false)
        }
    }

    private func stepBegan() {
        playsAtStepStart = controller.lessonPlays
        controller.setLessonSlowMotion(current?.slowMotion ?? false)
    }
}

// MARK: - Pointing at the table

/// What a lesson has singled out, handed down the game screen.
struct TutorialFocus: Equatable {
    var targets: Set<TutorialTarget> = []
    var enlarged: Set<TutorialTarget> = []
}

private struct TutorialFocusKey: EnvironmentKey {
    static let defaultValue = TutorialFocus()
}

extension EnvironmentValues {
    var tutorialFocus: TutorialFocus {
        get { self[TutorialFocusKey.self] }
        set { self[TutorialFocusKey.self] = newValue }
    }
}

/// Where each target is drawn, gathered up the view tree and resolved by the overlay —
/// through every rotation and scale between, the lesson's own enlargement included.
struct TutorialFrames: PreferenceKey {
    static let defaultValue: [TutorialTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TutorialTarget: Anchor<CGRect>],
                       nextValue: () -> [TutorialTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

enum TutorialStyle {
    /// How much bigger an enlarged target is drawn.
    static let enlarge: CGFloat = 1.35
}

private struct TutorialReportsBadgeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set on the hand, so only a card in it reports its SHOT ball: the same card in the
    /// discard pile would otherwise answer for it.
    var tutorialReportsBadge: Bool {
        get { self[TutorialReportsBadgeKey.self] }
        set { self[TutorialReportsBadgeKey.self] = newValue }
    }
}

extension View {
    /// Something a lesson can point at: it reports where it is, and grows while pointed at.
    /// Nil reports nothing.
    func tutorialTarget(_ target: TutorialTarget?) -> some View {
        modifier(TutorialTargetModifier(target: target))
    }
}

private struct TutorialTargetModifier: ViewModifier {
    let target: TutorialTarget?
    @Environment(\.tutorialFocus) private var focus

    func body(content: Content) -> some View {
        let grown = target.map { focus.enlarged.contains($0) } ?? false
        content
            .anchorPreference(key: TutorialFrames.self, value: .bounds) { anchor in
                target.map { [$0: anchor] } ?? [:]
            }
            .scaleEffect(grown ? TutorialStyle.enlarge : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: grown)
    }
}

// MARK: - The lessons

enum Tutorials {
    static let all = [passes, moves]

    static let passes: Tutorial = {
        let swing = CardLibrary.swingRight.id
        let dime = CardLibrary.dime.id
        return Tutorial(id: "passes", title: "Pass Cards", cardName: "Pass", face: .pass, legs: [
            TutorialLeg(title: "Playing a card", hand: [CardLibrary.swingRight], steps: [
                TutorialStep(text: "Every card type has its own colour, so you can read a hand at "
                                 + "a glance. Pass cards are blue.",
                             focus: [.handCard(swing)], enlarged: [.handCard(swing)]),
                TutorialStep(text: "This is a Pass. To play a card, tap it to raise it, "
                                 + "then tap it again.",
                             focus: [.handCard(swing)], enlarged: [.handCard(swing)]),
                TutorialStep(text: "The figure at the card's foot is what it does to SHOT, your "
                                 + "chance to score. SHOT belongs to the ball, so every Pass raises "
                                 + "it, and the other players' Passes raise it for you too.",
                             focus: [.cardBadge(swing), .shotHUD], enlarged: [.shotHUD]),
                TutorialStep(text: "Play Swing Right. It passes the ball to the player on your right.",
                             focus: [.handCard(swing)], advance: .pass, slowMotion: true),
            ]),
            TutorialLeg(title: "A Pass with an effect", hand: [CardLibrary.dime], steps: [
                TutorialStep(text: "Some Passes do more, and the words on the card say what. Dime "
                                 + "lets you pick who gets the ball.",
                             focus: [.handCard(dime)], enlarged: [.handCard(dime)]),
                TutorialStep(text: "Play Dime, then tap the player you want to pass to.",
                             focus: [.handCard(dime)], advance: .pass),
            ]),
        ], farewell: "That's Pass cards. Every Pass moves the ball and raises SHOT on the way.")
    }()

    static let moves: Tutorial = {
        let dribble = CardLibrary.dribble.id
        let drive = CardLibrary.drive.id
        return Tutorial(id: "moves", title: "Move Cards", cardName: "Move", face: .move, legs: [
            TutorialLeg(title: "Dribble", hand: [CardLibrary.dribble],
                        deckTop: [CardLibrary.drive], steps: [
                TutorialStep(text: "Move cards are green. You keep the ball after a Move, so you can "
                                 + "play as many as you like in one possession.",
                             focus: [.handCard(dribble)], enlarged: [.handCard(dribble)]),
                TutorialStep(text: "Dribble draws you a card, but costs 10% SHOT.",
                             focus: [.cardBadge(dribble), .shotHUD], enlarged: [.shotHUD]),
                TutorialStep(text: "Play Dribble: tap it, then tap it again.",
                             focus: [.handCard(dribble)], advance: .plays(1)),
            ]),
            TutorialLeg(title: "Drive", hand: nil, steps: [
                TutorialStep(text: "Your Dribble drew a Drive. Drive raises SHOT by 10%.",
                             focus: [.cardBadge(drive), .shotHUD], enlarged: [.shotHUD]),
                TutorialStep(text: "Play Drive.", focus: [.handCard(drive)], advance: .plays(1)),
                TutorialStep(text: "A Drive straight after a Dribble is a combo: SHOT +10% extra.",
                             focus: [.shotHUD], enlarged: [.shotHUD]),
            ]),
            TutorialLeg(title: "Combos", hand: [CardLibrary.dribble, CardLibrary.drive],
                        deckTop: [CardLibrary.drive], steps: [
                TutorialStep(text: "Now string one on purpose. Play Dribble, then Drive.",
                             focus: [.handCard(dribble), .handCard(drive)], advance: .plays(2)),
                TutorialStep(text: "That's a combo. A raised card's COMBO button shows which card "
                                 + "it pays off after."),
            ]),
        ], farewell: "That's Move cards. Play as many as you like before you pass or shoot.")
    }()
}
