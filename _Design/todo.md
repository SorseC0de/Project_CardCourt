# TODO

Things agreed on but not built. Newest at the top.

## The SHOT walkback, with the card text audit

Lower priority than getting the new cards right. Walk every SHOT +X% card and take 10% off
most of them: the Varenas and Variaballs, with the Game Breaks gone, should be boost enough to
keep play rolling. Done card by card — I read each one out — and the card text audit rides
along in the same pass.

## After the playtest, 2026-09-15

The deck back to 500: Snow Ball (not "Snow Ball It"), the injury rework and Make-or-Take Ball
and Hero Ball at 3 each.

- **Shelved**: a ball for "Discard any number of cards when shooting: SHOT +10% for each", the
  mechanic Turnaround Three lost. Room for it later.

- Court icon (Varena art) 100% ➜ 90% scale.
- Clamps as a keyword prints red; check every keyword colour against the new card colours.
- Variaballs: azure body, blue ring, gold name plate, orange name drop; name text azure over
  navy.
- Moves: green body, tangerine ring, and the Pass's whole name banner styling.
- Special Moves: dark blue ring.
- Re-import Injury_subject and Move_subject.
- **Intangibles are played by hand now, one per possession** — it changes pacing, hand sizes
  and rebounding. See "Intangibles become manual activation" below.

## How to Play

A short tutorial. The user has the specs. Lower priority than getting the cards right first.

## Varena and Variaball visuals

The rules for every card are in; these are the pictures, after the first playtest.

- **The Varena art**: every Varena draws the ISO court whole, no plate, until each has
  its own. The user is recolouring it.
- **The ball icons** are in for every ball but Med Ball, Bench Ball, Shufflebag Ball and
  Monster Ball, which wear the Variaball subject until theirs land. Each is drawn from the
  subject's ball, so every ball is the same size, over the name banner and under the name.
- **The plain Variaball's glow**: a multicolour glowing underlay beneath its ball, like Project
  Stars' Start button (`SpectrumFill` is that face, already lifted into this game). Not a
  priority, but wanted eventually. Not a
  priority, but wanted eventually.
- **Foot Ball's two gags**: GOOOOAAAAAAAAL on a make, and the flying goalie on a miss.
- **Hand Ball** shrinks the ball sprite to handball size.
- **Turnstile Tile** recolours the floor red and green each flip; **Grayvstone** turns it gray.
- **Grayvstone** finding no ball says so in the log only; it wants a brief animation.
- **Monster Ball's scene**: the shaking card and the next two are in. The light beams sparking
  from the discard pile to each winner are not.
- **Blight Ball's** Katamari layers on the ball.
- **Most Variaball Player** on the results screen.

## Intangibles become manual activation

Decided in the Intangible audit, 2026-09-13; how activation works is not designed yet. An
Intangible stops firing the moment it is drawn and is activated by the player instead, which is
why every purely negative one had to change: Shooting Slump, Unselfish and Villainous Reputation
were cut, and No Bag became Park Shark.

Free Agent stays out of the deck. Bringing it back is low priority.

## Stars start button text styling

Low priority, shelved: the text styling on the imported Stars start button still needs
correcting.

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

## The lit button says what is ready

**Project Stars' Start button is this game's word for *ready*.** `SpectrumFill` is that
face lifted as a fill — the angular sweep turns inside a shape rather than behind a pane —
and it is on the shoot button whenever the shot is special, with the card that armed it
standing beside the button.

"Special" is an override on the board or a bonus of 25% or more: Lethal Shooter off your
own glass, Splash Cousin from three, Hot Hand, Sniper. No ordinary Move reaches the line.

**This is meant to spread.** Wherever the game has been reaching for a HUD glyph to say
something is on, the answer is the lit control plus the card that did it. A glyph says
*something*; the card says *which*, and it is a drawing the player already knows from their
own board.

Still to do: the round call's number and the three's hand already wear it — the rest of the
places that want it have not been picked yet.

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

## The travel call is a table call

Making Traveling a standing rule rather than a card somebody sets down turned it into the
**"you didn't say Uno"** of this game: four Move cards in one possession is a call any
player at the table can make on any other, out loud, and everyone can count it because the
cards played this possession are face-up in front of the man playing them. Nothing enforces
it but the people sitting there.

**The app calls it automatically, and that is right.** Handling the ruling for you is what
an automated version is for — the same way a duelling sim is not trying to be a table and
nobody asks it to be. The two are different games to play, and the difference is understood
rather than a gap to close. Nothing to decide here.

**To revisit (the user's, when there is time):** Intangibles and Move cards that play around
the rule — cards that raise the limit, lower it for somebody else, or make a fourth Move
worth taking the call for. Med Ball is the first of them: it lifts the limit entirely.

## The deck's last slots (the user's, when there is time)

At 300 — the last two went to the swings, one left and one right. Two things the user has
flagged to look at after playing a full game under the new rules:

- **Intangibles to a round 30.** One more card, and nothing is spare now. It comes off the
  swings, which is 21/21/10 today — 20/20/10 frees two and keeps the ratio exactly, which
  is one for the Intangible and one over.

- **Special Moves outnumber Moves, and they are the sub-class.** Sixteen unique Special
  Moves against twelve unique Moves. By *cards* it is not close — 70 Moves to 16 — but a
  sub-class having more distinct cards than the class it belongs to is backwards however
  the copies fall. Bringing them to eleven or fewer kinds frees five or more slots and
  settles the Intangible at the same time.

The rework doc already says the Special Moves were never dissolved into Move and Intangible
the way the plan called for; they were only cut to one copy each. This is the same job.

## A bag HUD, drawn rather than exported

The user has the specs; it is purely visual, so it waits. **Bag Tag** goes with it — the
user will know what it means when we come back to this.

## Challenges

Every player gets **one challenge a game**: a shot taken to get out of a call — a free
throw, or an attempt at the current SHOT, undecided — and the game says **"BALL DON'T
LIE!"** whether it drops or not.

Not the final mechanics. What is settled is that challenges are going in, whatever shape
they end up: a call you can answer is the other half of officials you can read, and one a
game is the right number for a thing that should feel like spending something.


## The refs on the floor (recorded mid-audit, not built)

Comes in with the Travel revision — see the ref audit's record.

**Rounds end on shots only.** A turnover no longer ends the round unless a card says so.
In-round play speeds up and the one way a round closes becomes the one everybody can see
coming.

**A referee puts the ball in play.**

- At the top of a round he inbounds to a random player — **always the local seat while this
  is being developed**. Random first inbounder was always the plan; there is finally a
  reason to build it.
- He holds it in `Referee_holdball` and throws it in on `Referee_inbound`.
- On a turnover that came from a ref's call and did not end the round, **the same official
  who made the call** inbounds it, to a random player who is not the offender.

**Where they stand.** The two far posts go. The two that are left move up to halfway
between where they stand now and where the far ones were, scaled for the new depth, and two
new posts go in **south-east and south-west of the south player**.

**How they move.** Running is `Referee_run_N`. The looking is random and more often than the
players do it. The two bottom posts use the new corner looks — **the south-east one looks
NW and the south-west one looks NE**.

**The huddle.** On a stoppage the bottom refs warp up with everyone else, and the three of
them always form the same triangle in the **north-west corner of the court**: one facing
east, north-east of him one facing south on the 0 → 1 → 0 → 2 loop, and south-east of that
one facing west.

**To import:** `Referee_inbound`, `Referee_holdball`, `Referee_run_look_N`, `_NW`, `_NE`.

## The hair system

Hair as generated pixel art rather than drawn frames. `Hair_base.png` and `Hair_guide.png`
are imported and are what it builds against.

- **A pixel generator**, the shape of P-Stars' deprecated grass generator.
- **A designer bench**, with 8-way mirroring.
- **Few colours.** Not every 2-tone combination presents under a 32-colour palette, so the
  options are a curated list rather than a wheel.

**Low priority** — it is purely visual polish and nothing plays differently without it.

## Splash Ball has no effect yet

The art is imported and finished; the card does not exist. It waits on a **batch of 5 or 10
balls designed at once** rather than being written on its own.
