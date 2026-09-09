import SwiftUI

/// The front of the game.
///
/// Blue, because everything else in this build is navy — the table, the lobby, the
/// sheets — and the one screen that is not the game should not look like the game.
struct EntryScreenView: View {
    /// Into the match.
    var onPlay: () -> Void = {}
    var onLobby: () -> Void = {}
    var onGallery: () -> Void = {}
    var onHooper: () -> Void = {}
    var onWell: () -> Void = {}
    var onSettings: () -> Void = {}

    @State private var pad = Pad.shared
    /// Which door the ring is on. Opens on the game, which is the last of them.
    @State private var at = 5

    private enum Front {
        static let title: CGFloat = SwisshWordmark.Mark.size
        /// How far down the mark sits. Clear of the corners rather than tucked under
        /// them — it is the thing the screen is for.
        static let titleTop: CGFloat = 96
        /// The same height as the Play Online pill beside it: 15pt small caps in 7pt of
        /// padding, top and bottom.
        static let gear: CGFloat = 34
        static let tile: CGFloat = 58
        static let gap: CGFloat = 20
        /// The slab's own corner, so the ring follows its edge rather than boxing it.
        static let corner: CGFloat = 18
        /// One card in the hand behind the mark, and how far the fan sits above the
        /// mark's own top — enough that the arc runs behind the lettering rather than
        /// starting under it.
        static let hand: CGFloat = 100
        static let handLift: CGFloat = 44
    }

    /// Everything on this screen a pad can press, top to bottom the way the eye reads it.
    ///
    /// **A menu is a column.** Up and down walk it, and so do the bumpers — see
    /// `Row.runsDown`, which says the same thing about the mode picker. The ring opens on
    /// the game rather than on the first thing in the list, because that is what anybody
    /// pressing a button on the front screen came here to do.
    private var doors: [(label: String, run: () -> Void)] {
        [("Play online", onLobby),
         ("Settings", onSettings),
         ("Card Gallery", onGallery),
         ("My Hooper", onHooper),
         ("Swisshing Well", onWell),
         ("Check Rock!", onPlay)]
    }

    /// Whether the ring is on this door. **Nothing at all without a pad** — see
    /// `PadRing`.
    private func ringed(_ door: Int) -> Bool { pad.isAttached && at == door }

    private func walk(_ way: Int) {
        at = max(0, min(doors.count - 1, at + way))
    }

    private func take(_ action: Pad.Action) {
        switch action {
        case .up, .previous:  walk(-1)
        case .down, .next:    walk(1)
        case .tap, .flick, .primary: doors[at].run()
        default: break
        }
    }

    var body: some View {
        ZStack {
            CardPalette.blue.ignoresSafeArea()

            // **The hand behind the mark.** Declared first, so everything on the screen
            // is drawn over it and nothing on it can be pressed — see `EntryCards`. It
            // is deliberately wider than the screen: a fan that fits inside the edges
            // reads as a picture of a hand rather than as one being held out.
            VStack(spacing: 0) {
                EntryCards(width: Front.hand)
                    .padding(.top, Front.titleTop - Front.handLift)
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                SwisshWordmark(size: Front.title)
                    .padding(.top, Front.titleTop)

                Spacer()

                VStack(spacing: Front.gap) {
                    // Placeholders. Named and wearing their own art, so the shape of the
                    // screen is settled before any of them does anything.
                    tile("Card Gallery", art: .symbol("rectangle.stack.fill"),
                         run: onGallery)
                        .padRing(ringed(2), corner: Front.corner)
                    tile("My Hooper", art: .image("MyHooperIcon"), run: onHooper)
                        .padRing(ringed(3), corner: Front.corner)
                    tile("Swisshing Well", art: .image("SwisshingWellIcon"), run: onWell)
                        .padRing(ringed(4), corner: Front.corner)

                    // Last, and the only gold thing on the screen. Everything above it is
                    // somewhere to go; this is the game.
                    ChunkyButton(title: "Check Rock!", fill: CardPalette.gold,
                                 stroke: CardPalette.gold, shade: CardPalette.orange,
                                 size: 28, run: onPlay)
                        .padRing(pill: ringed(5))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }

            // The two corners: what the game is doing, and what you are doing to it.
            VStack {
                HStack(alignment: .top) {
                    playOnline
                    Spacer()
                    Button(action: onSettings) {
                        // On a square of its own, like every other control that has an
                        // edge. A bare glyph on the ground read as decoration.
                        Image("SettingsIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: Front.gear * 0.96,
                                   height: Front.gear * 0.96)
                            .foregroundStyle(.white)
                            .shadow(color: CardPalette.navy, radius: 0, x: 3, y: 3)
                            .padRing(ringed(1), corner: 8)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .onChange(of: pad.press) { _, press in
            guard let press else { return }
            take(press.action)
        }
    }

    /// Exactly as it was on the court before it moved here. It had earned its look on
    /// the one screen it lived on, and the migration was meant to change where it is and
    /// nothing else.
    private var playOnline: some View {
        Button(action: onLobby) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(CardPalette.gold)
                SmallCapsText(text: "Play online", font: Chrome.display, size: 15)
            }
            .foregroundStyle(.white)
            .shadow(color: Chrome.shade, radius: 0, x: 2, y: 2)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(CardPalette.red))
            .overlay(Capsule().strokeBorder(CardPalette.gold, lineWidth: 3))
            .compositingGroup()
            .shadow(color: CardPalette.orange, radius: 0, x: 4, y: 4)
        }
        .buttonStyle(.plain)
        .padRing(pill: ringed(0))
    }

    /// What a tile shows: a drawing of ours, or a stand-in until there is one.
    private enum Art {
        case image(String)
        case symbol(String)
    }

    /// The chair you sit in, carried onto the front screen: a blue slab with a gold rim,
    /// an orange drop under it, and heavy white type over a hard navy one. The lobby
    /// settled this look — see `MatchLobbyView.chair` — and a second one here would be
    /// two games.
    private func tile(_ title: String, art: Art, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Panel(fill: CardPalette.blue) {
                HStack(spacing: 12) {
                    Chip(side: Front.tile) {
                        Group {
                            switch art {
                            case .image(let name):
                                Image(name)
                                    .resizable().scaledToFit()
                            case .symbol(let name):
                                Image(systemName: name).resizable().scaledToFit()
                            }
                        }
                        .frame(width: Front.tile * 0.8, height: Front.tile * 0.8)
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.navy, radius: 0, x: 3, y: 3)
                    }
                    SmallCapsText(text: title, font: Chrome.display, size: 30,
                                  tracking: 1)
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.navy, radius: 0, x: 4, y: 4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Entry") { EntryScreenView() }
#endif
