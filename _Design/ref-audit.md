# The ref audit

Card by card, under the rules as they stand: three officials a round, dealt face up, none
retiring when called. **Decided, not built.** Measurements are from `./Tools/sim --refs`.

## The nineteen

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

**13 · Technical Foul** — it was never a turnover; a T gives free throws. It fires when a
player **targets another player with a card effect** — a pass, a clamp. The card still
resolves and the target takes 1 FT.

**14 · Clear Path Foul** — fires on clamping a player with **0 cards in hand, or while SHOT
is 0%**. It cancels the Clamp and gives the clamped player 1 FT. Fouling somebody who had
nothing between them and the basket, which is what the real call is.

**15 · Delay-of-Game Warning** — **silently disallows bonuses**, combo bonuses included. No
call, no gesture, no stoppage: a standing condition rather than a thing that happens.

**16 · Official Review** — **caps Intangible slots to 1** while he works. Play a new one and
you give up the old; the refs checking your bag. Reuses `intangibleSlots` and the question
`.awaitingIntangibleDrop` already asks.

**17 · Cleared to Play** — **parked**: `numberInDeck: 0`, with a comment saying why. Its
trigger is an Injury turning up and Injuries are parked, so it made 0 calls in 252 rounds
worked. The crew deck is its own pile, so parking one costs no slot anywhere.

**18 · Extravagant Mechanics** — kept as is. All three of its conditions are still in the
game.

**19 · Over-Varing Evidence** — kept as is. One of the later cards, and it holds up.

## New

**Crew Chief** — **any call, by any referee, retires the one who made it and draws a
replacement.** So a call spends the official who made it: the stage churns as it is used,
and a rule you have just played around is replaced by one you have not read yet. With the
retired ones shuffling back in, the man sent off can walk straight back out.

Note what this does to the whole crew: while he is working, every other referee is back to
**one call apiece** — which was the patch, arrived at from the other direction and as a card
rather than as a rule.

## The count

**Nineteen today.** Parking Cleared to Play takes it to eighteen; Crew Chief makes nineteen.
**One short of the twenty the deck wants** — a card still to be named.

## How the crew works

**A referee calls as often as his condition is met, all round.** One-call-a-round was a
patch I introduced and it is not the design: they stand for the whole round and are retired
at the end of it. **The retired ones shuffle back into the ref deck each round**, so the
same conditions can come back in new combinations.

**This is the one thing to measure the moment it is built.** Standing referees that called
every time is what produced 3,560 whistles and 614 turnovers a game with 467 of 500 games
unfinished: a violation hands the ball back in and the next pass trips the same call. The
revisions attack that directly — coin flips instead of blanket cancels, conditions instead
of always-on, turnovers no longer ending rounds — but it is not gone by assumption, and the
shot clock is the only thing left that closes a round nobody can score in.

## The call animations

More than one now, and which one plays is the card's.

- `Referee_tech` — one held frame. A **T of light energy** fires from where his hands form
  the T, hits the offending player, and sets off `SparkleBurst` and a 1s jitter on them.
- `Referee_travel` — six frames. **All three referees run it at once**, from where they
  stand, which is the joke.
- `Referee_Call` — the pose and the rattle, for everything else.

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

**Cards that force another player to do something.** Without them people simply play around
a ref for the whole round, which makes a stage everybody can read into a stage everybody can
dodge. Lob is the one that already does it — the man it finds owes a shot — and the Clamps
and Moves want more of that shape, so a referee's condition can be walked into by somebody
other than the player who would trip it.

**The counter-clamp Moves want their own audit.** Spin Move, Crossover, Pump Fake and Flop
all clear every Clamp for free, which is far too cheap now that a defender is a task they
are meant to work at. They should start clearing other things — balls, refs, Intangibles —
so answering a defender costs a choice.
