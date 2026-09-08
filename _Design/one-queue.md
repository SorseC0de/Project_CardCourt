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

## What it unlocks: "What just happened?"

> "A button that walks back through the last few events for people failing to keep up with
> all the stuff flying by on screen. Cause sometimes you can go a really long time not
> being able to actually play."

This is the case *for* the queue rather than a use of it, and it is the strongest one.

The log already exists and does not answer this. It is **text, released a beat at a time**
— it tells you a Clamp landed, not that a man walked out and swiped at your hand. What
somebody who lost the thread wants back is the *scene*: the card held up, the name plate,
the ball crossing, the referee arriving. None of that is recoverable from a line of prose,
and none of it can be rebuilt from `GameState`, because the state is where things ended up
rather than how they got there.

With one queue it is close to free. The steps are already the scenes; keep the last
however-many in a ring and replay them with the rules skipped. Nothing new has to be
recorded, because recording is what the queue is.

It also answers a real complaint about the game rather than about the code. Three other
players take their turns and a lot happens that is *done to you*, and at four players the
stretch where you cannot act is long enough to lose the thread entirely. A game where you
spend that long watching owes you a way to catch up.

Worth noting the same window would give a guest a way to *re-sync*: replay is the same
mechanism as catch-up, which is what a device rejoining a match needs.

## What it unlocks: multiplayer that cannot quietly disagree

> "You write the netcode to literally just compare queues every resolution. It shouldn't be
> possible for them to disagree if every action is just broadcast to push to both queues."

Nearly. One correction, and it makes the idea stronger rather than weaker.

**The queues cannot be identical**, because of redaction. A step reading "North drew Pump
Fake" on the host has to reach West as "North drew a card" — West is not allowed to know
which. So the payloads differ by design, and comparing them would report a desync on every
draw.

What *can* be identical is the **shape**: which steps, in which order. So each side keeps a
rolling digest of the steps it has drained — kind and identity, not contents — and every
message carries the host's. Matching digests mean the two are the same game however
differently they are allowed to see it; a mismatch names the exact step where they parted.

That is the real win, and it is not "disagreement is impossible". Anything derived locally
can still drift — a roll made on the wrong side, an appearance nobody sent, a presentation
that cancelled halfway. The queue narrows the surface to *steps the host pushed*, and the
digest makes whatever is left **loud instead of silent**. Today a desync is found by two
people holding phones next to each other and reading numbers off them.

**The digest does not need the queue.** Events already cross unredacted — only the state is
redacted — so a rolling hash of applied events can be built against the stream as it
stands, and become the queue's comparison mechanism later. That is worth doing first,
because it is the diagnostic the whole problem has been missing.

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

---

# Where it stands — 2026-09-08

The way in has been taken. **`GameState.pending: [Step]`** exists and is the only place
an owed thing lives.

## What is on it

Six kinds, and they were six separate fields:

| step | was | paid by |
|---|---|---|
| `revealBreak` | `pendingBreaks` | `drainBreaks`, in deck order, while the draw chain is held |
| `spendHand` | `handsOwed` | the settle |
| `handOverBall` | `pendingInbound` | `handOverBall`, at a possession's end |
| `returnBall` | `returnsTo` + `returnLeg` | the settle, once there is a possession |
| `shootAtOnce` | `shootsAtOnce` | the settle, once there is a possession |
| `takeTheLine` | `pendingFreeThrows` | `takeTheLine`, at a possession's end |

`overflowing` is **not** a step and should not become one: being over the slots is a fact
about a board, so it is read rather than remembered. That was itself a bug once — a set
that was sifted rather than rebuilt left boards at six on a three-slot table.

## The property, and what enforcing it found

> A possession may not open owing a step the drain could have paid.

The soak checks this every time the floor is handed to a player. It found **73 cases on
the first run**. Two were real: an empty hand was being treated as a debt still owed
rather than one already settled, so Free Agent's toll followed a man into the next hand he
was dealt. The rest were the check being too strict about the two steps that are paid at a
possession's *end*.

`./Tools/sim --steps` reads the list from outside the rules over 300 games:

```
step            owed   per game   waited (moves)      longest   left at the end
  revealBreak     owed and paid inside one play, so never seen from out here
  spendHand       never owed
  handOverBall     29       0.10             0.57            1                 5
  returnBall       96       0.32             0.12            1                 0
  shootAtOnce      74       0.25             0.24            1                 0
  takeTheLine      84       0.28             0.87            3                 0
```

Steps are paid within a move of being owed, and the longest anything waits is three. The
five left at a final whistle are games that ended with a ball still to be handed over —
the debt dies with the game, which is right, but it is the one number here worth an
opinion.

## What is deliberately not done

**Two drains, one list.** `drainBreaks` runs Breaks while it holds the draw chain open;
the settle runs the rest at the edge of a play. Those are genuinely different edges, and
merging them changes *when* things happen rather than how they are book-kept. What is gone
is the second **place** an owed thing could live, which is where every bug of this shape
came from.

**`pendingClamps` is still a field.** Defenders waiting to land is an owed action by the
same definition, and it has its own bug history — but the landing rules are intricate
(`clampLanding`, `clampMagnet`, `pendingClampVoid`) and the court reads the field directly
to draw them in the air. It is the obvious next one, and it wants somebody watching.

**Presentation is still the second queue**, and still the hard part. Nothing here has
touched it. Until it is steps, there is no replay ring and no per-seat step redaction — so
the two big unlocks in this document remain unlocked.

## The next decision

Whether the settle and the break drain become one. That is the change that makes "pushed
to the end and resolved one by one" literally true, and it is the first one that can
change the game rather than only the bookkeeping. It wants a day with somebody watching,
not a night.
