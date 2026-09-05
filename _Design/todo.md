# TODO

Things agreed on but not built. Newest at the top.

## The cuts

A suite of Move cards for the cuts, the way the passes cover the passes. Agreed while
adding Clear Out — which is the one that already exists, since a clear-out *is* a cut, the
one where you take your man away from the ball.

The obvious ones, and what each would have to mean on a table:

| Cut | What it is | The shape of the card |
| --- | --- | --- |
| Backdoor | Behind a defender who has overplayed you | Something that pays off *being* clamped |
| Give-and-Go | Pass it and cut for the return | A pass out and a pass back — Right Back already is this, so a Move version would have to differ |
| Curl | Around a screen, towards the rim | SHOT, with the size of it depending on what came before |
| Flare | Off the screen the other way, out to the arc | Upgrades to a three |
| Baseline | Along the endline, weak side | Moves you, not the ball — the only real use for a positional card |
| Iverson | Across the top, off two screens | Two of something, or a card that only works played second |

Not started, and deliberately parked: the deck is already thick with Moves. This is a
suite to design as a set once the pass ratio is where it should be.

## The deal, from the inbound

Low priority, both parts. The inbound looks right now; the dealing that follows it does
not.

**The deck should travel and bow.** It already can — `DeckStage.travel` banks into a move
and `bow(toward:)` turns and dips at each stop, and `CourtStage.open` uses both for the
opening lap. Nothing calls them for an ordinary deal, so the pile sits still and only the
card moves. What is missing is the wiring, not the movement.

**The dealt cards are tiny.** A card in flight comes out far smaller than a card in a hand,
so a deal reads as something being flicked rather than dealt. Worth measuring what the
flight is actually sized against before changing the number — see `CardFlight` and the
`dealer` in `CourtStage`.

## The dealing itself

The deck's own performance landed — the jostle, the bank into a flight, the bow at each
stop. What the cards do once they leave it has not. `CardDealer.fly` throws a slab from the
deck to a player on a plain arc and that is the whole of it: no fan, no arrival, nothing
that reads as a card being *given* to somebody rather than moved to their coordinates.

Parked deliberately. The deck reads right, which was the hard part.

## The action clock

A live match cannot stop because one player pocketed their phone, and the game turns out
to already carry its own answer to that — every decision has a legal way to decline it:

| Asked for | If the clock runs out |
| --- | --- |
| A move | **Shoot.** Always legal, whatever is in the bag and whatever the SHOT reads. |
| An inbound | The house throws it in — the one decision with no way to decline it. |
| A rebound bid | **Nothing.** Zero cards. |
| Cards fed into a Turnaround Three | **Nothing.** |
| A free throw | **A violation.** No points, the same as standing at the line and not shooting. |

Paired with the free draw every possession opens with, that closes the loop: four absent
players still draw, still shoot, still leave the board to nobody, and still run out of
rounds with a winner at the end of them. Nothing about an idle match can stall it.

`Pacing.actionClock` — one number for every decision, because a player learning two
different clocks is worse than one that is occasionally generous.

**Not done: the player can't see the clock.** It runs on remote seats only, so nobody is
timed out without at least knowing the game moved on — but the local player's own clock
cannot fairly be enforced until there is a countdown on screen. That is the next piece.

## Both modes

Two ways to play the same game, and both are first class:

- **Live** — `GKMatch`. Everybody in at once, one authoritative host. Someone who wants to
  sit down and play a game of basketball.
- **Async** — `GKTurnBasedMatch`. Take a turn, close the app, get Apple's own "your turn"
  push, keep six games running at once. The Words With Friends way.

Built in that order. Live is written; async is a second `MatchTransport` and nothing else.

### Why it takes to both

Worth writing down, because it is not true of most card games and it is the reason this is
cheap rather than a rewrite:

- **Every decision is a discrete choice from a hand.** Nothing is timed and nothing is
  dextrous, so a decision made in four seconds and one made the next morning are the same
  decision.
- **Whistles resolve themselves.** A Whistle is armed in advance and fires off the state
  when its trigger comes round — there is never a "do you want to respond?" prompt waiting
  on an absent player. That prompt is exactly what stops most trap-card games from working
  asynchronously, and this game does not have one.
- **The free-throw mini-game lives entirely inside the shooter's own turn**, so it needs
  nobody else to be present.

### The rebound board, which was the one problem

Bidding is simultaneous, and async has no such thing. It turns out to need no rules change
at all: after a miss, the match cycles the four seats as bid turns. Bids are already hidden
until they are read out, so nobody learns anything by going later, and the board resolves
when the fourth lands. `Rules.resolveRebound` already takes all four bids at once and the
host already collects them as they arrive — see `bidsFromWire`. Async collects them the
same way, just over four turns instead of four seconds.

So: no rules change, no state change, and no second set of redaction rules. A second
transport, and turn cycling for the board.

The push and time-sensitive entitlements are already in place for it. Until then they are
only useful for invites.

## Multiplayer: what only you can do

The code is in `Net/`. None of it can authenticate until the app exists in App Store
Connect, and that is not something the code can arrange for itself:

Done: the App ID carries the Game Center capability (it was ticked automatically when the
first leaderboard was added), and `ProjectCardCourt.entitlements` carries Game Center, push
and time-sensitive notifications.

What is left is testing, and it wants **two physical devices** signed into different Apple
accounts. Development builds hit the Game Center sandbox on their own. Two simulators on
one Mac is not a reliable way to find a match.

Note that App Store Connect has no "enable GameKit" switch and never did — the capability
on the App ID is the switch, and ASC's Game Center section is for leaderboards and
achievements. Real-time matchmaking needs nothing configured there at all.

## Jersey numbers

Players wear a number on the sprite. In a pixel font — the sheet is pixel art and an
anti-aliased digit sitting on it reads as a sticker.

There are 10–15 pixel fonts installed, so the first step is a **gallery** to look at them
side by side rather than picking one from a name: every font rendered at the sizes a
jersey actually uses, over the uniform colours, at the court's own scale. Whichever one
survives being small and being on a moving sprite wins.

Open: whether the number is drawn into the sheet or laid over it, and whether it turns
with the player.
