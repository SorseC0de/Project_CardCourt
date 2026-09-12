import CoreGraphics
import Foundation
import GameController
import Observation

/// A physical controller, in the game's own words.
///
/// **Semantic, never literal.** Nothing outside this file knows what a DualSense calls its
/// buttons. The game is handed "walk left", "take this one", "put it back" — and this
/// decides which of the many things a player might have pressed meant that. Two sticks, a
/// d-pad and two shoulder buttons all say the same handful of things, and a screen that
/// had to know about each of them would be a screen that breaks on the next pad.
///
/// **One reader.** Every press is published here with a stamp and routed by `GameView`,
/// which is the only thing that knows what the table is currently asking. Views that each
/// watched the pad for themselves would all answer the same button at once.
@Observable
@MainActor
final class Pad {
    static let shared = Pad()

    /// Whether one is connected. **Nothing on screen changes until it is** — this is a
    /// touch game a pad can also drive, not the other way round, so no hint, ring or
    /// prompt appears for a player who has not plugged anything in.
    private(set) var isAttached = false

    /// The last thing asked for. **Watch the stamp, not the action**: pressing left twice
    /// is two events and an `Equatable` action alone cannot say so.
    private(set) var press: Press?

    /// Where a stick or the touchpad is being pulled right now, in the same terms a drag
    /// on glass reports — positive height is *down* the screen. Nought when nothing is
    /// being held. Only the free throw reads this; it is the one thing in the game that
    /// is a gesture rather than a choice.
    private(set) var pull: CGSize = .zero

    /// A pull that has just been let go, carrying what it measured at the moment it went.
    /// Stamped for the same reason `press` is.
    private(set) var release: Release?

    struct Press: Equatable {
        let action: Action
        /// Which of the four it came off, when it came off one of the four. **Carried
        /// beside the action rather than instead of it**: a face button means one thing
        /// ordinarily and another while the table is asking which player — see
        /// `GameView.take(_:)`.
        let face: Face?
        let stamp: Int
    }

    /// One of the four, by where it sits on the pad rather than by what it does.
    ///
    /// **The diamond is the point.** Square is the left one, circle the right, cross the
    /// bottom and triangle the top — which is the same shape as four players round a
    /// table, so a prompt asking which of them can hand each seat the button drawn where
    /// that seat is drawn. See `Seat.face(viewedFrom:)`.
    enum Face: String, CaseIterable, Hashable {
        case square, cross, circle, triangle
    }

    struct Release: Equatable {
        let pull: CGSize
        let stamp: Int
    }

    /// Everything a pad can say. Named for what it does at the table rather than for the
    /// button it came off.
    enum Action: Equatable {
        /// Walk the row the table is asking about — the hand, the men on the floor, the
        /// cards on offer. What the row holds is the gate's business, not the pad's.
        case previous, next
        /// **The flick, without the gesture.** Triangle, and triangle alone: the result
        /// of throwing a card at the table, which is playing it.
        ///
        /// **Up is not this.** Up is where your thumb rests and where it goes on the way
        /// to anywhere else, and a thumb that grazes it should not play a card.
        case flick
        /// Up and down the screen. Navigation only — in a stacked list they walk it, and
        /// down puts a raised card back. Neither ever commits anything.
        case up, down
        /// **The one thing the screen is offering.** The right trigger, which is not a
        /// second face button: wherever the ring happens to be, this presses whatever the
        /// game is holding out — SHOOT on your turn, the bid, the spend, the take.
        case primary
        /// The one under your thumb, and the right trigger with it. A tap on whatever is
        /// focused — twice on a card is a look and then a play, exactly as two taps on
        /// glass are.
        case tap
        /// Out of this. A raised card goes back down, an open sheet closes, a question
        /// with a way of declining takes it.
        case back
        /// A closer look at what is focused, without choosing it.
        case inspect
        /// The game's own pause.
        case pause
    }

    // MARK: - Feel

    /// How the pad is read. **Whole frames**: the poll runs on the game's own beat, so
    /// every delay here is a count of frames rather than a number of seconds that lands
    /// between two of them.
    private enum Feel {
        /// A sixtieth, which is what everything else in the game moves on.
        static let beat: Double = 1.0 / 60

        /// How far a stick must go before it counts as a direction at all.
        static let throwDistance: Float = 0.55
        /// And how far back it must come before it can say the same thing again. A single
        /// threshold makes a stick held near the edge chatter.
        static let letGo: Float = 0.35

        /// How long a direction is held before it starts repeating, and how often it
        /// repeats after that. Slow enough that a nudge is one card, quick enough that a
        /// full hand is a held thumb rather than eight presses.
        static let beforeRepeat: Double = 0.40
        static let thenEvery: Double = 0.10

        /// How far a finger must travel on the touchpad for it to read as a pull, as a
        /// share of the pad's own width. Below this it is a rest, not a gesture.
        static let touchFloor: CGFloat = 0.04

        /// How far a stick must go before it counts as a *pull*. **Far shorter than a
        /// direction**: walking a row is a yes-or-no answer that a resting thumb must not
        /// give by accident, and a free throw is a distance being measured — reading
        /// nought until it is more than half way over would make the shot jump.
        static let pullFloor: Float = 0.12
    }

    // MARK: - Reading it

    /// Which physical things are down, so a press is the moment one goes from up to down
    /// rather than every frame it is held.
    private var held: Set<Key> = []
    /// Which way the sticks and the d-pad are being pushed, and since when — the pair
    /// that turns a held thumb into a repeat.
    private var heading: Action?
    private var headingSince: Date?
    private var headingFired: Date?

    /// Where a finger landed on the touchpad, so what is reported is how far it has
    /// travelled rather than where it happens to be.
    private var touchFrom: CGPoint?
    /// Whether anything was being pulled last frame, which is what makes a release an
    /// event rather than a reading of nought.
    private var wasPulling = false

    private var stamp = 0
    private var watch: Task<Void, Never>?

    private init() {
        for name in [Notification.Name.GCControllerDidConnect,
                     .GCControllerDidDisconnect,
                     .GCControllerDidBecomeCurrent] {
            NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.takeStock() }
                }
        }
        // Wireless pads announce themselves rather than being found, so this is what
        // picks up one that was already paired when the app opened.
        GCController.startWirelessControllerDiscovery()
        takeStock()
    }

    /// Whether anything is plugged in, and the poll started or stopped to match. **No
    /// loop while nothing is connected**: a game played on glass should not be reading a
    /// pad sixty times a second for the whole match.
    private func takeStock() {
        isAttached = !GCController.controllers().isEmpty
        if isAttached, watch == nil {
            watch = Task { [weak self] in await self?.keepReading() }
        } else if !isAttached {
            watch?.cancel()
            watch = nil
            forget()
        }
    }

    /// Everything held, let go of. Called when the pad goes, so a button that was down as
    /// it disconnected is not still down when another is plugged in.
    private func forget() {
        held = []
        heading = nil
        headingSince = nil
        headingFired = nil
        touchFrom = nil
        pull = .zero
        wasPulling = false
    }

    private func keepReading() async {
        while !Task.isCancelled {
            read()
            try? await Task.sleep(for: .seconds(Feel.beat))
        }
    }

    // MARK: - One frame of it

    private func read() {
        // Off `input`, not the old gamepad profile: every value read off that makes
        // GameController walk the loaded images to see who is asking, sixty polls a second.
        guard let controller = GCController.controllers().first else { return }
        let input = controller.input
        readButtons(on: input)
        readHeading(on: input)
        readPull(on: input, isDualSense: controller.productCategory == GCProductCategoryDualSense)
    }

    /// What each button says. **The whole map, in one table** — a pad that calls its face
    /// buttons something else is a row here, not a change anywhere in the game.
    private func readButtons(on input: GCControllerLiveInput) {
        // Cross on a DualSense, A on an Xbox pad.
        edge(.tap, input.buttons[.a], as: .tap, face: .cross)
        // **Not a second cross.** The trigger is the shortcut past the row: whatever the
        // screen is offering, without walking to it.
        edge(.r2, input.buttons[.rightTrigger], as: .primary)
        // Circle. Out of whatever this is.
        edge(.back, input.buttons[.b], as: .back, face: .circle)
        // Triangle, which is the flick under a thumb that never left the face buttons.
        edge(.flick, input.buttons[.y], as: .flick, face: .triangle)
        // Square. A look at something without taking it.
        edge(.inspect, input.buttons[.x], as: .inspect, face: .square)
        // The bumpers walk the row, so a hand can be read without leaving the sticks.
        edge(.l1, input.buttons[.leftShoulder], as: .previous)
        edge(.r1, input.buttons[.rightShoulder], as: .next)
        // Options on a DualSense, Menu on an Xbox pad.
        edge(.menu, input.buttons[.menu], as: .pause)
    }

    /// Fires once, on the way down.
    private func edge(_ key: Key, _ button: (any GCButtonElement)?, as action: Action,
                      face: Face? = nil) {
        guard let button else { return }
        if button.pressedInput.isPressed {
            guard !held.contains(key) else { return }
            held.insert(key)
            say(action, face: face)
        } else {
            held.remove(key)
        }
    }

    /// Which way the row is being walked, from the d-pad and either stick, with the
    /// repeat that a held thumb earns.
    ///
    /// **One heading between the three of them.** A thumb on a stick and a thumb on the
    /// d-pad are the same hand asking for the same thing; read separately they walk the
    /// row two cards at a time.
    private func readHeading(on input: GCControllerLiveInput) {
        let now = pushing(input)

        guard let now else {
            heading = nil
            headingSince = nil
            headingFired = nil
            return
        }
        guard now == heading, let since = headingSince else {
            heading = now
            headingSince = Date()
            headingFired = nil
            say(now)
            return
        }
        // Held. The first repeat waits; the rest come at a steady clip.
        let waited = Date().timeIntervalSince(headingFired ?? since)
        let due = headingFired == nil ? Feel.beforeRepeat : Feel.thenEvery
        guard waited >= due else { return }
        headingFired = Date()
        say(now)
    }

    /// The one direction all three inputs add up to, or nil for a hand at rest.
    ///
    /// Sideways beats up and down: the row is walked far more often than a card is
    /// played, and a stick pushed left and a little high should not throw a card at the
    /// table.
    private func pushing(_ input: GCControllerLiveInput) -> Action? {
        let leftStick = input.dpads[.leftThumbstick]?.xyAxes.value
        let rightStick = input.dpads[.rightThumbstick]?.xyAxes.value
        var x: Float = (leftStick?.x ?? 0) + (rightStick?.x ?? 0)
        var y: Float = (leftStick?.y ?? 0) + (rightStick?.y ?? 0)
        if let dpad = input.dpads[.directionPad] {
            if dpad.left.isPressed { x -= 1 }
            if dpad.right.isPressed { x += 1 }
            if dpad.down.isPressed { y -= 1 }
            if dpad.up.isPressed { y += 1 }
        }

        // Whatever it was doing has to be let go of before it can say it again — see
        // `Feel.letGo`, which is what stops a stick resting near the edge from chattering.
        let held = heading != nil
        let over = held ? Feel.letGo : Feel.throwDistance
        if abs(x) >= over { return x < 0 ? .previous : .next }
        if abs(y) >= over { return y > 0 ? .up : .down }
        return nil
    }

    private func say(_ action: Action, face: Face? = nil) {
        stamp += 1
        press = Press(action: action, face: face, stamp: stamp)
    }

    // MARK: - The one gesture

    /// The free throw's pull, off a stick or off the DualSense's own glass.
    ///
    /// **Reported the way a drag is.** `FreeThrowView` measures a pull down the screen and
    /// a drift across it; whatever a player pulls it with, that is what arrives — so the
    /// shot does not need to know which it was.
    private func readPull(on input: GCControllerLiveInput, isDualSense: Bool) {
        var now = stickPull(input)
        if isDualSense, let touch = touchPull(input) { now = touch }

        let pulling = now != .zero
        // Let go: what it measured at the last frame it was held is the throw, because
        // the frame it is released on reads nought.
        if wasPulling, !pulling {
            stamp += 1
            release = Release(pull: pull, stamp: stamp)
        }
        wasPulling = pulling
        pull = now
    }

    /// A stick's own displacement. There is no travel to measure — where it is pushed to
    /// *is* how far it has been pulled.
    private func stickPull(_ input: GCControllerLiveInput) -> CGSize {
        let sticks = [input.dpads[.leftThumbstick], input.dpads[.rightThumbstick]]
            .compactMap { $0?.xyAxes.value }
        // Whichever hand is doing the work. Added together, a thumb resting on the other
        // stick drags the aim across.
        guard let stick = sticks.max(by: { hypot($0.x, $0.y) < hypot($1.x, $1.y) }),
              hypot(stick.x, stick.y) >= Feel.pullFloor
        else { return .zero }
        // Down the screen is up the axis reversed: a pad reports +1 for forward.
        return CGSize(width: CGFloat(stick.x), height: CGFloat(-stick.y))
    }

    /// How far a finger has travelled across the touchpad since it landed.
    ///
    /// The DualSense's pad reports where a finger is, not that it is there — nought is
    /// both the middle and nobody touching it. A finger at rest in the middle is a finger
    /// that has not thrown anything, so reading the two the same way costs nothing.
    private func touchPull(_ input: GCControllerLiveInput) -> CGSize? {
        guard let touchpad = input.dpads[GCInputDualShockTouchpadOne] else { return nil }
        let finger = touchpad.xyAxes.value
        let at = CGPoint(x: CGFloat(finger.x), y: CGFloat(finger.y))
        guard at != .zero else { touchFrom = nil; return nil }

        guard let from = touchFrom else { touchFrom = at; return .zero }
        let moved = CGSize(width: at.x - from.x, height: -(at.y - from.y))
        guard hypot(moved.width, moved.height) >= Feel.touchFloor else { return .zero }
        return moved
    }

    /// **What this pad calls its own buttons.** `GameController` hands every button an
    /// SF Symbol for the controller actually plugged in, so a DualSense says cross and an
    /// Xbox pad says A without the game knowing either name. Nil when nothing is attached
    /// or the pad does not offer one, and the caller draws nothing rather than guessing.
    ///
    /// Apple's own rule: these glyphs are for telling a player which button to press, and
    /// nothing else.
    func glyph(for face: Face) -> String? {
        guard let input = GCController.controllers().first?.input else { return nil }
        switch face {
        case .cross:    return input.buttons[.a]?.sfSymbolsName
        case .circle:   return input.buttons[.b]?.sfSymbolsName
        case .square:   return input.buttons[.x]?.sfSymbolsName
        case .triangle: return input.buttons[.y]?.sfSymbolsName
        }
    }

    func glyph(for action: Action) -> String? {
        guard let input = GCController.controllers().first?.input else { return nil }
        switch action {
        case .tap:     return input.buttons[.a]?.sfSymbolsName
        case .back:    return input.buttons[.b]?.sfSymbolsName
        case .flick:   return input.buttons[.y]?.sfSymbolsName
        case .inspect: return input.buttons[.x]?.sfSymbolsName
        case .primary: return input.buttons[.rightTrigger]?.sfSymbolsName
        case .pause:   return input.buttons[.menu]?.sfSymbolsName
        default:       return nil
        }
    }

    /// The four face buttons **in the shape they sit in**: left, bottom, right, top.
    ///
    /// Square, cross, circle, triangle. The order matters because the court is a diamond
    /// and so is a thumb's reach — the man on the left of the floor should be the button
    /// on the left of the pad, and nobody should have to learn that. Borrowed during a
    /// "which of them" question; see `Seat.face(viewedFrom:)`.
    /// The physical things a press is remembered by. Their own names, so the map above is
    /// the only place a button's meaning is written down.
    private enum Key: Hashable {
        case tap, back, flick, inspect, l1, r1, r2, menu
    }
}
