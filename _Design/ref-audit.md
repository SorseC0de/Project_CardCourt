# The ref audit

Card by card, under the rules as they stand: three officials a round, dealt face up, none
retiring when called. **Decided, not built.** Measurements are from `./Tools/sim --refs`.

## Decided so far

**1 · Travel** — *On ~[Move]: flip a coin. If tails, #[TOV] +1 (Travel).* The move-limit
lowering leaves this card and becomes a Clamp instead.

**2 · Shot Clock Violation** — kept. The trigger widens from *lowered* to **any** change to
the clock, so Outlet Pass trips it too — messing with the clock at all is the offence.

**3 · Double Dribble** — becomes literal: it fires on **playing the same Move card twice in
a row**. Its old effect moves to Discontinued Dribble.

**4 · Back Court Violation** — *On ~[Pass]: flip a coin. If tails, #[TOV] +1.* Same shape as
Travel: the blanket-cancel refs that fired every round become coin flips.

**5 · Discontinued Dribble** — takes Double Dribble's old effect: cancel a Dribble, Retire
1, TOV +1.

**6 · Charge** — keeps its dunk trigger, and **charges the turnover**. A charge is a
turnover. The general rule: most refs should hand out TOV +1, which is what rounds no
longer ending on a turnover pays for.

**7 · Foot On The Line** — kept as is.

**8 · Offensive Foul → Palming** — a charge *is* an offensive foul, so the name collided.
Effect unchanged.

**9 · Goaltending** — the trigger moves to **shooting over a Clamp**. The shooter takes the
points and the round ends; it stays a round-ender, which is consistent because it is a shot
call. A positive ref: because the crew is public it is a planned free basket, and it makes
people not want to guard you.

**10 · Blocking Foul** — **does not void the Clamp** any more. The Clamp lands and works,
and the clamped player takes 1 FT. That turns "don't clamp" into "clamp anyway and trade
their 2 or 3 for a possible 1". The calling referee works the free-throw scene and then
inbounds it straight back to the clamped player himself.

**11 · Flagrant Foul** — fires only on a Clamp that would force cards into **Retirement**,
and voids it.

**12 · Flagrant Foul II** — no more full-hand Retires; those are devastating in a game like
this. It fires on **clamping an already-clamped player**: the new clamper Retires 2 and the
clamped player takes 1 FT, and the Clamp still lands. Ganging up costs three or four cards
and a free point, and is still worth it when somebody has to be stopped.

## Clamps, decided alongside

**Full-Court Press** — the only non-standing Clamp, which should not be a thing now that
defenders are assignments. It becomes the advantage canceller: **Must #[Retire] 1 card to
play a ~[Move] card**, which turns the Move engine's +1s into break-evens and the
break-evens into losses. **#[Clear]: the ball touches all 4 hands.** The table clears it,
but getting two of the four keys quickly means passing yourself.

**Clamps come off passes entirely.** You play one, target who it lands on, and pass to them
if you want it to bite now — or pass elsewhere and it waits for them. **No out-of-turn
play**: a Clamp can never be aimed at whoever holds the ball right now, because the planned
passive online mode cannot carry interrupts. **Floor General aims Clamps too**, and can send
one back at the clamper, so stripping his Intangible first becomes a real play.

**The counter-clamp Moves want their own audit.** Spin Move, Crossover, Pump Fake and Flop
all clear every Clamp for free, which is far too cheap now that a defender is a task they
are meant to work at. They should start clearing other things — balls, refs, Intangibles —
so answering a defender costs a choice.
