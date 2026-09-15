# Implementation queue: Varenas and Variaballs

Ordered plan for turning [varenas-and-variaballs.md](varenas-and-variaballs.md)'s 45 designed
cards into working code. Nothing here is written yet — this is the plan to verify before any
Swift changes start. Referenced types/files are the real ones as of this branch's base
(`one-queue`).

## The central refactor

Today, each Game Break bakes its own one-off field onto `GameState` — `shotCeilingThisRound`
(Rock Fight), `skipsNextDraw` (Fresh Ball), `freeRebound` (Off the Backboard), and a dozen more
in that shape. That works for one-shot events; it does not scale to persistent state, because
every rule everywhere that touches SHOT, draws, referees, or clamps would need to know about
every field.

The replacement is two general slots:

```swift
var courtCard: Card?                // nil == the table's own Cardwood
var ballCard: Card?                 // nil == Regulation Ball
```

Game logic asks "what's on the court / what's on the ball" and dispatches on the card's
`id`. Most
of the one-off `GameState` fields this replaces get deleted once their card is ported, rather
than kept alongside the new system.

## Phase 0 — Data model

- [x] `Card.swift`: add `CardType.varena` and `CardType.variaball` (replacing `.gameBreak` for
      everything except the 3 Injuries, which stay auto-firing exactly as now).
- [x] `Card.swift`: new `VarenaEffect` and `VariaballEffect` structs, same style as
      `GameBreakEffect` — one field per mechanic, not one struct per card. Draft field list
      below in Phase 3, grouped by mechanic rather than by card, since several cards share a
      field (e.g. every flat-SHOT-delta court is one field, not six).
- [x] `GameState.swift`: add `courtCard` (non-optional, defaults to `CardLibrary.cardwood`) and
      `ballCard` (optional). Remove the one-off fields listed per-card in Phase 3 as each is
      ported, not in one sweep — keeps every commit buildable.
- [ ] `CardType.gameBreak` shrinks to the 3 Injuries only; confirm nothing else reads
      `CardType.gameBreak` expecting the old 30.
      *Confirmed: its readers are the Game Break announcement, the Whistle draw trigger,
      the gallery's section list and the Injuries — none counts the old 30.* **Done for the
      deck:** the Game Breaks are out. Injuries are their own type, with Devastating Injury its
      sub-type, so nothing dealt is a Game Break any more. Each Break's rules code
      stays until its replacement is built, then goes.

## Phase 1 — SHOT override hierarchy

`ShotModifiers.override` (`ShotMath.swift`) stays exactly what it is — one optional
`ShotOverride`. What's new is that more than one card can now want that single spot at once: a
standing Court override, a standing Ball override, and a played Special Move's override can all
be live on the same shot, where before only one override source ever existed at a time.
Everything fights for the one slot; the hierarchy just decides who wins it.

- [x] `ShotMath.swift` or wherever `ShotModifiers` gets assembled for a shot: before `override`
      is ever set, gather every live candidate and keep only the highest-ranked one —
      **Intangible > Court > Ball > played-card override** — in one place, rather than letting
      whichever one runs last silently clobber the others.
- [x] Confirm Special Moves' own overrides (Slam Dunk, Full-Court Heave) rank where "played
      card" sits in that list — same tier as an ordinary Move, below Ball and Court.
- [x] Unit-test the hierarchy directly: Court + Ball both live, Ball alone, Intangible beating
      both, no override at all.

## Phase 2 — Slot lifecycle rules

- [x] Playing a Varena or Variaball replaces `courtCard`/`ballCard` outright — no stacking
      (confirmed: Variaballs never stack).
      *The slots hold the played `Card`, read through `currentCourt` and `currentBall`. The card
      replaced goes to the pile; the table's own Cardwood never does.*
- [x] One per player per possession, per slot — new counters alongside the existing
      `movesPlayedThisPossession` pattern.
- [x] **Held like any card.** A lock, a pass-only Clamp or a shot owed bars a Varena or a
      Variaball the same as anything else. *An "always playable" exemption was written here
      once. It was never a rule.*
- [x] **Playing one is an action**, like playing any card: it uses up a first action and a
      combo does not read through it.
- [x] Whistles can now fire on these plays (reversed from the old Game Break rule) — confirm
      `Whistle.trigger` gets a case for "Varena played" / "Variaball played" for Tile Tampering
      and Over-Varing Evidence.
      *So far: a Whistle watching any non-Whistle play already fires on them. The two named
      triggers land with Tile Tampering and Over-Varing Evidence in Phase 3.*
- [x] Cardwood is a playable card (decided): playing it changes the court back to basic. Five
      in the Standard deck.

## Phase 3 — Per-card wiring, grouped by system

**Built 2026-09-14.** Every card below is in the deck and has a test in `Tools/slottests.swift`;
`./Tools/sim --slots` reads out how often the house plays each one. The rulings are in the
design doc.

Grouping by what the card touches, since the plumbing is shared within a group even where the
numbers differ. `TBC` counts are still open — do not invent numbers when porting.

**Flat SHOT delta (Varena, additive):** Prime Parquet (+10), Lacktop (−10), Gravi-Gym (−10, no
dunks), Con-crete (Moves −10). One field: `shotDelta: Int`, plus `noDunks`/`movesOnly` flags
where a card pairs a delta with a rule.

**Flat SHOT delta, ball-holder-scoped (Variaball):** none currently additive-only; see override
group below — Med Ball and Blaze/Snow Ball are the closest and each needs its own shape
(ceiling, and per-pass accumulator, respectively).

**SHOT override (Court, ranked above Ball):** Spazzphalt (random 0–100 by 5s).

**SHOT override (Ball):** Bag'n Ball (= hand count), Brick Ball (flat 25%).

**SHOT ceiling (Ball):** Med Ball (cannot exceed 50%).

**Per-pass accumulator (Ball):** Blaze Ball (+10/pass, stacking), Snow Ball (−10/pass,
stacking) — both explicitly ignore other pass modifiers, so they read the pass event directly
rather than going through the normal SHOT-delta pipeline.

**Hand-size floor (Varena):** Tri-hard Tiling (cap 3), Recharging Resin (refill 5). Needs a
"hand size rule" concept checked at draw phase and after every discard/draw, since these are
standing constraints, not one-time.

**Turn-scoped draw (Varena/Variaball, active player only):** MVPiquia (leader refills to 5),
Recharge Rock (double draw for turn), Shufflebag Ball (shuffle hand into deck, redraw same,
then normal draw), Roleplayer Polymer (everyone *but* the turn player draws 1), Variaball Vinyl
(the turn draw goes to a random player instead).

**Global one-time-per-play draw/discard (Varena):** Mop Maple (everyone reshuffles hand into
deck), Malice Palace (turn player discards whole hand pre-draw).

**Referee interaction (Varena):** Smacktop (Whistles can't activate; enhances Clamps),
Policeum (referees never leave; existing 3-ref cap bounds it), Clearcoat Court (wipes refs,
clamps, injuries, waiting effects, and Intangibles every possession), Contact Court (a landed
Clamp sends its victim to the line).

**Clamp interaction (Varena):** Smacktop and Contact Court above, plus Traderous Tarmac
(reassign a clamp on you; counter-clamp prompt, immediate-vs-standing split per clamp type —
see the design doc's table mapping each of the 5 existing Clamps).

**Injury interaction (Varena):** Recoverena (clear on play; standing, new injuries become a
draw instead), Clearcoat Court (above).

**Rebound board (Varena):** Boarder Court (Roswell Reach off your own miss, needs ≥1 bid).

**Ball-state accumulation (Ball):** Blight Ball (injuries travel with the ball and its cards,
Katamari-stacking, discarded with the ball).

**Ball-on-receipt trigger (Ball):** Bench Ball (skips the receiver's whole turn via inbound,
not pass), Dishtracting Ball (receiver discards 1, post-draw), Hand Ball (swaps hands with the
passer on receipt).

**Move/Pass economy (Ball):** Foot Ball (Moves/Passes lock instead of discard, clears at
possession end — needs the `#[Lock]` machinery `Double-Team`/`Triple-Team` already use),
Dishcount Ball (costs 1), Frostbite Finish and Con-crete (Moves cost more — see above).

**Slot-crossing (Varena reaching into the Ball slot):** Vintage Varnish (Variaballs disabled
outright, plus shot clock 14, no threes, 1 Intangible per player — the most invasive card in
the set), Grayvstone (ball becomes the last ball in the Variaball discard, every possession —
open question: what happens before anything's been discarded).

**Hand rotation (Varena):** Carousel Court (rotate one seat, every possession).

**Point-value / shot-shape (Varena):** Kiddie Court (no threes, +10%, dunks +10% more),
S.O.S — Sell-Out Stadium (a three may instead shoot as a two at double SHOT).

**Information (Varena):** Dim Dome (SHOT hidden from all but the ball holder — needs `AIPolicy`
to actually withhold it, not just hide it in the HUD, per the open question below).

**Clock (Varena):** Tick-Tock Tile (playing any card also ticks the shot clock).

**Alternating/toggling (Varena):** Turnstile Tile (shooter's SHOT alternates +25/−25 every
turn; visual is a red/green recolor).

**Shot attempt (Ball):** Brand New Ball (25% a shot attempt is a turnover instead, 3).

**Intangibles that read the slots:** Varsitile (no one-per-possession limit on either slot;
once per possession, exchange the Varena and/or ball for one in the discard, and one use can
do both), Brawl Handler (changing the ball removes your own Clamps), Baller (changing the ball
yourself draws 1). Dealt once Variaballs are. Fundamentalist's ball discard is already built.
**Like That does not stop a Variaball lowering SHOT** — every ball SHOT reduction built here
has to get past it.

**The eponymous / signature card (Ball, 1-of, non-persistent):** Variaball — resolves and
discards immediately on play, no standing effect. Pulls from the Variaball discard pile,
digital rolling programmatically per the design doc.

**Whistles (new trigger, not a slot card):** Tile Tampering (cancels a played Varena, TOV +1),
Over-Varing Evidence (same, for a Variaball).

## Phase 4 — Visual work

- [ ] The `∀` glyph as drawn art through the existing plate-and-subject icon system — not set
      as text (font support for U+2200 is not guaranteed). Needed before any Varena card face
      can render its type icon.
- [ ] Court recolor states: Turnstile Tile (red/green flip), Grayvstone (gray).
- [ ] Ball sprite states: Handball-sized ball (Hand Ball), soccer ball with hexagons (Foot
      Ball) plus its two gags (GOOOOAAAAAAAAL text, the flying-in goalie on a miss),
      Katamari-style accumulating layers (Blight Ball).
- [x] Dim Dome's SHOT-hidden state in the HUD (flip the % readout face down).

## Phase 5 — AI

- [x] `AIPolicy` must not read the true SHOT number while Dim Dome is out, or the AI plays with
      information the human player doesn't have. This has to be a model-level withholding, not
      a view-level hide.
- [x] `AIPolicy` needs a policy for *when* to play a Varena/Variaball at all, and which one —
      currently there's no analogue since Game Breaks auto-fired and were never chosen.

## Open questions carried over, unresolved

- Grayvstone before anything exists in the Variaball discard pile.
- The ratio audit set every count: 105 copies against 79 slots. The whole deck is reviewed again
  before they are built.
- The art budget: which cards get bespoke floor art versus an overlay (tint/marking/badge) on
  the existing court SVG.
- Salary-cap theme and Cardtan remain parked, not designed — not part of this queue.

## Suggested build order

1. Phase 0 + Phase 1 together — nothing else compiles meaningfully without the slot fields and
   the override hierarchy fixed.
2. Phase 2 (lifecycle rules) — needed before any card can actually be played end-to-end.
3. Phase 3, weakest-dependency groups first: flat SHOT delta, then hand-size floors, then
   turn-scoped draw — these touch the fewest other systems and prove the slot pattern out.
4. Phase 3, the rest — referee/clamp interactions and slot-crossing cards last, since they
   touch the most existing systems (Clamps, Whistles, the rebound board) and are likeliest to
   surface a design gap.
5. Phase 4 and 5 alongside whichever card in Phase 3 needs them, not as a separate pass at the
   end — Turnstile Tile's recolor should land in the same commit as Turnstile Tile's logic.
