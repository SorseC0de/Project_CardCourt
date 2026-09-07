# One queue

> "This whole game should honestly be built off a queue system. Everything just gets
> pushed to the end of the queue and then the engine just resolves things 1 by 1. The
> queue should be so robust that EVERYTHING can be pushed to it. Prompts, name display,
> ball movement."

Right, and the evidence is a night's worth of bugs that are all the same bug.

## What actually goes wrong today

A play does not finish in one place. It sets some state, calls a few helpers, and leaves
the rest **owed** — to be paid by whoever happens to run next. Nothing enforces that
anybody does.

- Declining a counter returned early without calling `settleHands`, so a Right Back's
  return leg stayed owed forever. The ball sat with the receiver until the clock ran out:
  a shot-clock violation with no visible cause. Reported weeks ago, found only because a
  seeded test drifted onto it.
- Fixing that exposed the opposite: `settleHands` clears `returnLeg` *before* sending the
  ball home, so the guard against a return asking for another return read nil and armed a
  fresh trip every time.
- A ball handed over by Benched left the return still owed, so the loop had to be broken
  by hand at the hand-over.
- `resolveMode` acted as whoever *answered* rather than whoever *played*, because the
  actor was a field somebody had to remember to read.
- On the presentation side the same shape: a cancelled chain left cards marked as still in
  the air, permanently, because the un-marking was at the end of a function that never
  reached its end.

Every one is a step that had to happen somewhere else, and the somewhere else was a call
somebody had to remember to make. A queue does not fix that by being tidier. It fixes it
because **an owed step is an item, and the engine cannot finish while items remain**.

## What it would look like

One list of `Step`s, drained one at a time. A step is anything the game does that another
step might need to wait for:

- move the ball, tick the clock, draw a card, discard, land a clamp
- ask a question — the drain stops on a prompt and resumes on the answer
- say something on the floor: a name plate, a call, a cutscene, a card held up

`Rules.apply` stops returning `[GameEvent]` and starts *pushing*. Nothing is owed, because
owing something is pushing it. `settleHands` disappears: what it does is a step, queued
where it belongs rather than swept up at the edges.

## What is genuinely hard

1. **Presentation is already a second queue**, and a better one — `beat(of:)`, `release`,
   the split at the shot. The two would have to become one, or the split becomes the new
   seam.
2. **Multiplayer redaction is per seat.** The host would drain the real queue and send each
   guest the steps it is allowed to see. That is probably *easier* than today, where a
   guest replays a batch of events and hopes its presentation matches.
3. **The AI reads state, not steps.** It would ask at a drained point, which is what it
   effectively does now.
4. **It is not a night's work**, and it is not the multiplayer fix.

## The way in that is not a rewrite

The queue can be introduced under the existing rules rather than instead of them:
`GameState` gains a `pending: [Step]`, the handful of things currently owed — the return
leg, `pendingInbound`, `pendingFreeThrows`, `handsOwed`, `shootsAtOnce` — become items on
it, and one `drain` runs where `settleHands` runs today. That is five owed things becoming
one mechanism, with every call site still in place. If that holds for a week, the rest
follows the same way.

Nothing here is scheduled. It is written down so the decision is a decision.
