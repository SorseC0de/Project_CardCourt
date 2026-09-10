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

## Card text audit — stopped at Whistles

Working through the card text type by type, in the order the sheet lists them: Pass, Move,
Special Move, Clamp, **Whistle**, Game Break, Intangible.

**Done:** Pass, Move, Special Move, Clamp.
**Next:** Whistle, then Game Break, then Intangible.

Picking it back up 2026-09-08.

The bench is on the front screen, under Settings → **Card text**. It shows the three
wordiest cards of whichever type at both sizes a card is read at, and `print` puts the
whole of `CardTextStyle` on the clipboard and into the console on the `[bench]` channel.

Everything but four colours is one set of numbers across all seven types — see
`CardTextStyle`. The four that are per type: the words, the mechanics inside them, the
inner ring, and the drop under the name plate. The drop under the big icon is a fifth.

## Base pass SHOT is 10%, not 5%

Changed 2026-09-08, on evidence rather than feel.

The base was nerfed to 5% back when the pool was mostly passes and Moves. It is not that
pool any more: Game Breaks, Whistles and Clamps all push SHOT down, there are 31 / 20 / 5
of them, and **more Clamps are planned**. Five was a number set against a game that no
longer exists.

What it does, measured over 500 Classic games:

|                     |    +5 |   +10 |
|---------------------|------:|------:|
| PTS                 | 12.35 | 15.60 |
| AST                 |  4.80 |  6.17 |
| **TOV**             |  2.01 |  **0.39** |
| shots/game          | 12.65 | 13.47 |
| made                | 42.9% | 52.5% |
| forced shots        |   48% |   34% |

The turnover collapse is the point rather than a side effect. Every Move played is clock
spent, and at 5% a hand had to spend a lot of it before a shot was worth taking — so
possessions died on the shot clock. At 10% they end in a shot. Move counts fall right
across the board (Dribble 1.09 → 0.87, Hesi 1.43 → 0.95, Pump Fake 1.74 → 1.14), which is
the same fact from the other side.

**The goal is a quick, exciting card game.** A possession that ends in a shot is the game
happening; one that ends on the clock is the game not happening.

Ten cards carry it: four take it from `MatchRules.passShotBonus` — Swing Left, Swing
Right, Skip Pass, Behind-the-Back — and six name their own: Nutmeg, No-Look, Touch Pass,
Right Back, Hand-Off, Bullet Pass. `standard` is built from `classic`, so the preset
number is one place.

Open: **Behind-the-Back's sheet row names no percentage at all**, so it silently takes the
match bonus. Every other pass says its number. Worth deciding whether that is deliberate.

**Overnight 2026-09-09:** the scoreboard and the front screen's hand of cards — see [Overnight — the board and the front screen.md](Overnight%20—%20the%20board%20and%20the%20front%20screen.md).

## Name things explicitly, everywhere

**A global pass over the project to make every name say what it is.** Not a style
preference — a legibility one: the project has to be readable without me sitting next to
it.

The fault, in the user's own example from `ScoreboardView`: a `Board` struct with members
called `head` and `row`. *Head what? Row what?* They should be `headScale`, `rowSize`.
Shorthand saves characters nobody is paying for — this is an IDE with autocomplete — and
costs the one thing that matters, which is knowing what a thing is for six months later.

Rules: **no one-character names**, no bare nouns that need their context to make sense, and
a name that says what it measures rather than what it sits next to. Applies to locals,
members, parameters and closure arguments alike.

Scope: the whole project, in one deliberate pass rather than opportunistically — a rename
half-done is worse than not started.

## Next up: the card face

**The words are jam-packed.** ~~Every dial is already at a value that was chosen; what has
to be decided is what comes off the card.~~ **Done.** What came off: the row of small marks
at the foot, all but the ball. What changed: the face is **Geoform**, set smaller (0.075)
in a wider column (padding 0.120) with no tracking, on a black wash over the court at 0.15.
The big icon lost its drop shadow and moved up to 0.100.

Still open on the face: the icons' front layers, being drawn now — see `type-icons.md`.

**Intangibles wear gold twice.** The ask: *the outer stroke should always be the card's own
body colour.* Where it stands, a card front has exactly one stroke — `CardFrontView.border`,
drawn in `CardInk.ring` (gold for Intangibles, navy for everything else) — and outside it
sits a band of the body colour, which is already the rule being asked for. So the second
gold is somewhere I have not found: needs a pointer to the screen it was seen on.

Worth knowing while looking: `Theme.color(for: CardType)` is a **second, stale copy** of the
type colours that says Intangibles are gold and Moves are green, against `CardPalette`'s
black and orange. Only the gallery's filter capsule reads it, but it is exactly the kind of
duplicate that produces a gold card edge nobody can find in the drawing code.
