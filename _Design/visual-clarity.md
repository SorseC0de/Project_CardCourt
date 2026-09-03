# Visual clarity — TODO

Players find the opening confusing. That feedback predates this build; it came back on the
Classic version too, so it is the game and not the port.

**The target is Phase 10 / Exploding Kittens, not Uno.** Uno is out of reach for a game
with this many card types, and chasing it would cost the game its depth. But the shelf
above — a game you can teach in one round rather than three — is reachable, and it is the
difference between beating Munchkin and HexHex and merely being compared to them.

## Helpers, not rewrites

**The card face does not change.** It is the tabletop artifact, and it has to read the same
in both. What changes is the **dim area around a card that has been raised** — presently
empty scrim — which is where helpers go.

The argument for them is parity, not power. At a table someone says *"this one goes to
John"* in a fraction of a second, and everyone can see the layout, count the cards in a
hand, and watch a face. Digital has none of that channel and has to earn it back. The give
and take runs both ways: some things are simply easier to discern in person, and helpers
are how the screen catches up rather than how it gets ahead.

So the helper is what a person sitting opposite would have said out loud.

## Worth saying in that space

- **Who it lands on** — *"→ Tanaka"*, with her seat lit on the court behind. The card still
  says "Swing Left".
- **The SHOT sum**, small, beneath the card — *45 + 10 = 55%*. The delta is arithmetic
  homework; the total is the decision, and it is the number confusion gathers around.
- **What it is worth right now** — Flop with two Clamps on you is two free throws.
- **Why it is greyed** — *"nobody has passed to you"* beats a grey card with no reason.
- **What a Whistle is watching for** — a condition, not a target.

Clamps and Whistles each want a **single small sentence**, restoring the explicitness that
was stripped off the card body to keep the face short. Not a rules quote — the one line a
person would have said.

## What a helper must not claim

Some things genuinely are not known when a card is raised, and a helper that guesses is
worse than one that says nothing.

- **A Clamp lands on whoever receives the ball next**, which is undecided at that moment.
  *"Whoever gets it next"* is honest; a name is not.

## Also in a clarity pass

- First-run explanation of the four phases. The card gallery ([card-gallery.md]) is the
  reference; this would be the teaching.
- The SHOT stack is invisible: a shot at 45% does not say which Clamp took 25 off it.
  `ShotResolution.steps` already carries the breakdown — the dev log prints it today.
- Rebound bids: it is not obvious that everyone bids at once, and hidden.

## Where it lives

`InspectedCardView` and the raised card in the hand both already dim the screen around a
single card and already sit over the court. The space is there and empty.
