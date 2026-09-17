# The Move, Special Move and Intangible audit

2026-09-17. Fifty-eight cards, one at a time, looking for where to put **Ref Retirement**
now that the officials stand for a whole round and can only ever be changed. Everything
here is built; the counts land on exactly 300.

| Outcome | Count |
| --- | --- |
| Revised | 44 |
| Stood as printed | 10 |
| Parked | 2 — Great Conditioning, Like That |
| Moved type | 1 — Equalizer, to the officials deck |
| New | 1 — Floater |

## The five rules the audit changed

- **A dunk wants a full Move bar**, not SHOT 50%. The finish at the rim is the end of a
  drive, so the possession's movement pays for it — and every Move card becomes a step
  toward one. `GameState.moveLimit(for:)` is the single owner, so the Travel meter and the
  dunk's gate can never disagree.
- **Every shooting Special Move names one of the three finishes.** `bonusPointOnMake` and
  the `isThree` derived from it are gone; what a make is worth comes from the ShotType,
  which means Foot On The Line takes a Special Move's extra point exactly as it takes a
  button's.
- **Every Move card replaces itself** with a draw.
- **Clear Out is the only multi-clear.** Everything else names one defender.
- **A Three always wants five cards**, whatever the bag limit is — so Sixth Man widens the
  bag without pushing the three out of reach.

## Two flags that were declared and never read

Both found by the audit, both fixed:

- **`requiresShotType`** — written onto Charge, Palming and Foot On The Line when the shot
  triangle went in, and never once checked. Charge was waving off layups, Palming was
  waving off dunks, and a crew holding all three cancelled every shot in the game. Reading
  it took turnovers from **46.5 to 3.4 a game** and calls from **116.9 to 13.3**.
- **`swapsOnRetire`** — Rookie Official's whole card. Now: the first non-standing card you
  spend in a possession buys a differently-named one back out of Retirement.

## Moves

| Card | × | What changed |
| --- | --- | --- |
| Clear Out | 5 | Clears **all** Clamps on you at the cost of the possession, and takes Crossover's old bonus: Draw 1 card for each Cleared. The only multi-clear. |
| Crossover | 5 | Clear **target** Clamp — singular, and it may be an opponent's. Out of the Dribble family; keeps the Ankle Breaker combo. |
| Dribble | 10 | Stands. Pot of Desires. |
| Drive | 10 | Stands. |
| Flop | 3 | **Compulsory** as your first action while it is in hand, which makes its own "no Clamps, TOV +1" a live risk. |
| Hesitation Dribble | 5 | Shot Clock **-03**. Pot of Extravagance to Dribble's Desires. |
| Pound Dribble | 5 | Shot Clock cost removed — nothing to do with a pound dribble. |
| Pump Fake | 5 | Target **any number** of Clamps on you: SHOT +15% and Shot Clock -01 extra for each. **They stay on you.** The shoot-over-clamps card, and picking fewer is how you avoid a violation. |
| Rhythm Dribble | 5 | Must be played **after a Dribble**. |
| Spin Move | 5 | Out of the Dribble family. Bonus replaced: **Retire target Ref**, or Reassign target Clamp from anyone to anyone. |
| Stepback | 5 | Bonus gains: attempt a Three with **2 fewer cards** immediately after. A stepback is separation, and separation is what people shoot threes off. |
| Triple Threat | 3 | Stands. |

## Special Moves

Every shooting one now carries its finish. The dunks and threes are **bypasses** of the
button gates, which is what makes them worth a slot.

| Card | × | Finish | What changed |
| --- | --- | --- | --- |
| 2-Hand Jam | 1 | dunk | Draw 1, SHOT +25%. The Retire-any-number half is its bonus now and only opens off a Rebound. |
| Bankshot | 1 | layup | Draw 1. Heads: +25% and ignore target Clamp. Tails: -25% and Draw 1 extra. |
| Buzzer Beater | 1 | three | + Draw 1. |
| Dagger Three | 1 | three | + Draw 1. |
| Euro Step | **3** | — | Draw 1, then flip 3 coins: each Heads is SHOT +15%, a card, **and a step on the Move meter**. The Travel risk is inherent, and so is the walk to a dunk. |
| Fadeaway Three | 1 | three | Renamed. Ignores Clamps **and Refs**. |
| Floater | **3** | layup | **New.** Draw 1, SHOT +30%, ignore target Clamp. Completes the generic auto-shot trio. |
| From the Hash | 1 | three | You may **Retire target Ref**. |
| From the Logo | 1 | three | You may **Retire target Ref and/or Ball** — it reaches twice. |
| Full-Court Heave | 1 | three | Retires the Ball outright, ignores Clamps and Refs, and may take a player's Intangible. |
| Putback Tip | 1 | layup | + Draw 1. |
| Skyhook | 1 | layup | The draw becomes **a card out of Retirement** — the Kareem homage. |
| Slam Dunk | **3** | dunk | + Draw 1. |
| Three-Ball | **3** | three | + Draw 1. Restored to a multiple; it was always meant to be the plentiful one. |
| Tomahawk | 1 | dunk | + Draw 1. |
| Turnaround Three | 1 | three | The hand it dumps **retires a Ref**, and only 5 or more buys SHOT = 100%. |
| Open Three | 1 | three | Renamed from Wide-Open Three. **Digital-only.** 2+ Passes this round is SHOT +50%; once everyone has touched it, it renames itself in hand to **Wide-Open Three** at 100%. |

## Intangibles

| Card | What changed |
| --- | --- |
| Ball Pounder | A **trade**: on a Dribble you may spend 3 ticks for a card and SHOT +10%. |
| Baller | Fires on **any** ball change, by anybody. |
| Board-Crasher | **Any** Rebound, not only your own miss. |
| Brawl Handler | Clear **target** Clamp when you change the ball. |
| Catch & Shoot Specialist | Stands. |
| Clutch Gene | Stands. |
| Competitive | **SHOT +25% when shooting over a Clamp** — which walks straight into Goaltending's window, by design. |
| Officially Infamous | Renamed from Dirty Player. **Retire any Ref that calls a violation on you.** |
| The Equalizer | **Moved to the officials deck.** Any player may Retire him and their hand for SHOT = 100% and everyone's points levelled to theirs. Exempt from both reshuffles, so a game gets exactly one. Button reads EQUALIZER. |
| Franchise Player | While passing: **Retire an active Ball, Ref, or Intangible.** |
| Freethrow Merchant | Take 1 FT when Clamped — it no longer blanks the Clamp. |
| Fundamentalist | Cannot play Special Moves. Retires the active Ball. **Draw 1 extra card per Move.** |
| Generational Whistle | Wording only, with the loop guard printed. |
| Gravity | All Clamps **must** target you; the assist is on a **make**. |
| Great Conditioning | **Parked** — Injuries are out of the pool. |
| Hot Hand | SHOT +25% if you scored **with the active Ball**. Change the ball and the chain restarts. |
| Lethal Shooter | Stands — deliberately stronger than Board-Crasher. |
| Like That | **Parked** — it blanks every SHOT cost in the game, its owner's included. |
| Moves At Own Pace | Stands. It refers to the violations, not the cards. |
| Park Shark | Sits **Special Moves** down, not Moves — so the bar can still fill and dunks come back. |
| Point God | Draw 1 card **while passing**. |
| Roswell Reach | Wording: one card **extra**. |
| Shot Creator | Wording, with the recursion guard printed. |
| Sixth Man | **Your max Bag size is 6.** |
| Sniper | Stands. |
| Southpaw Shooter | Stands — deliberately risky, so a strong player can abuse the negative-SHOT cards. |
| Splash Cousin | On a Three, spend it to put **Splash Ball** in play. |
| Varsitile | Variaballs only. Once a possession, exchange the Ball or an Intangible for one in Retirement. |
| Floor General | Stands — the card the whole audit leaned on. |

## Splash Ball

Outside the deck entirely. **Splash Cousin is the only thing that puts it in play**, and
Retiring it **removes it from the game** rather than sending it to Retirement.

- SHOT = 100% on Three-Point attempts.
- On a make: 💧💦🌊🐬🐳🫧 and **"IT'S A SPLASH PARTY!"**
- A guaranteed three, then a scramble, because it sits there until somebody deals with it.

## The counts

| | Before | After |
| --- | --- | --- |
| Pass | 105 | 103 — Right Back 5 → 3 |
| Move | 70 | 66 — Flop and Triple Threat 5 → 3 |
| Clamp | 60 | 60 |
| Special Move | 16 | 25 — Three-Ball, Slam Dunk, Floater, Euro Step all ×3 |
| Intangible | 29 | 26 |
| Variaball | 20 | 20 |
| **Deck** | **300** | **300** |

Officials: 21 → **22**, with The Equalizer. Splash Ball sits outside both.


## After the audit

Four more changes, taken in the same pass:

- **Knock → Force** everywhere. Nutmeg and the new combo below.
- **Misdirection** — a new combo: **Crossover → Swing Left/Right**. The swing goes the
  *other* way and **Forces 1 card to the next player**, so a Crossover followed by Swing
  Right actually passes left. Sell one direction, go the other.
- **Bench Ball → Long Ball.** Bench Ball killed the pace; Long Ball says **Layups are shot
  as Threes**. They are still layups — Palming still watches them, an empty hand still pays
  its bonus — but they go up from range, are drawn from range, and score 3. The dunk and
  the three are untouched.
- **Make-or-Take Ball → Foul Ball.** Effect unchanged.

Every Variaball now has art: Long Ball, Foul Ball and Shufflebag Ball were the last three
without, and all are imported with in-play sprites.

Both prompts the audit created — `.awaitingRetirement` and `.awaitingClampsNamed` — are now
drawn on `CardChoiceView`, the same sheet every other question uses.
