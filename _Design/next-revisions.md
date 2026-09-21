# Next revisions

Written at the checkpoint that became `main` — the quarters rework, the Clamp prices, the
Move bar, the travel call, and a pass that travels again. Nothing below is built yet.

## Behaviour

### Cards forced on you out of turn ignore the hand limit

A draw somebody else causes — a rebound, a card that deals to the table, anything that is
not your own turn's card — goes into the hand whatever the limit says.

**Why.** Otherwise forcing draws is a way of inflating your own SHOT on your turn: the
limit is checked when it suits you rather than when the cards arrive.

**What pays for it.** A **discard phase** at the top of a possession, *before* the draw:
over the limit, you are asked to put cards down until you are not. Named that in the code
— it is a phase of a possession, like the draw is.

### The SHOT plate swells when SHOT goes up

A brief swell on the plate as a reading changes, so a number moving is something you see
rather than something you notice. Cards that overflow into SHOT travel to the plate first
and the swell lands as they arrive.

### Any number of Clamps a turn

The one-per-player limit is restraint enough. Two reasons: hands full of Clamps with
nobody to put them on are dead, and clamping *yourself* to clear them is a combo the
current limit hides.

### Quarters, not Rounds

"1st Quarter", "2nd Quarter", with the ordinal's letters set as superscript.

## Communication

### Every prompt shows the card it is about

Any question a card asks presents that card — its face and its text — in the banner at the
top of the screen, so what you are answering is readable while you answer it.

**This has to be airtight**: a global rule with no card slipping through. A question with
no card behind it on screen is the bug this is fixing.

### A pre-shot sequence, on every shot that is not a free throw

Five seconds at the outside:

1. The screen dims.
2. The SHOT plate stands in the middle — the old free-floating one — reading the **raw**
   SHOT.
3. To its left, a queue of overlapping cards: everything adding to the final number —
   Intangibles, the ball, the floor. **Not** the Moves already played that built the raw
   reading. To its right, everything taking away from it — Clamps and the rest.
4. The adders go in one at a time. Each absorbs into the plate, which swells, and the
   figure flashes green as it climbs — past a hundred if that is where it goes.
5. Then the detractors, the same way: a swell inward and a red flash.
6. A last swell settles the total — capped where the rules cap it — and the plate moves to
   a corner. The screen undims and the shot plays as it always does.

## Carrying on

### The game survives being killed

Closing the app and opening it again offers the game back: resume where it was, or quit to
the title. The state is already one value — see `GameState` — so what this wants is a
place to put it and a decision about what a half-played scene resumes as.

## Answered already

**A 14-second quarter against the current 24**, 500 games each, asked because a game with
no scoring-ends-the-round might now run long:

| | 24 | 14 |
|---|---|---|
| PTS | 37.46 | 20.81 |
| AST | 12.36 | 6.81 |
| REB | 24.73 | 13.36 |
| TOV | 6.54 | 5.51 |
| shots | 40.21 | 21.88 |
| made | 38.8% | 39.3% |
| log lines | 430 | 266 |
| unfinished | 0 | 0 |

Fourteen does not trim the game, it halves it: a little over half the shots and a little
over half the points. Turnovers barely move, because most of them are the clock itself
and there are the same four of those either way — which makes them a much larger share of
what happens. Somewhere between the two is the question worth asking; 20 would land near
33 points a game if it scales evenly.
