import SwiftUI

/// The player's own man: who he is and what he looks like.
///
/// Everything here is appearance except the name and the number, and even those are
/// appearance as far as the rules are concerned — see `HooperKit`, which no part of the
/// model reads. The point of the screen is that the figure at the top of it changes as
/// you change him, so nothing is chosen from a list of words.
///
/// **It fits on one page.** No scrolling: a screen you have to scroll to see the effect
/// of a choice you just made is a screen where half the choices are made blind. Every
/// block is sized as a share of what is left after the figure has taken its half, and the
/// two long lists — faces and colours — wrap into rows rather than running off the side.
/// The earlier scrolling version is kept whole in `HooperScrollLayout`.
struct HooperView: View {
    var onDismiss: () -> Void = {}

    @State private var kit = HooperKit.shared
    @State private var seen = SeenCards.shared
    @State private var pose: Kit.Pose = .front
    @State private var pickingFavourite = false

    private enum Sheet {
        /// Art pixels per point. Half of one, and deliberately: this is exactly one and a
        /// half times the five he was drawn at. At seven and a half points an art pixel is
        /// twenty-two or twenty-three device pixels rather than a round number of them,
        /// which is a fraction of a percent at this magnification and nothing you can see.
        static let scale: CGFloat = 7.5
        /// **Floor to crown, in art pixels.** Sized off the tallest thing he does rather
        /// than off the biggest sheet: the shot is drawn in a 48-frame but only thirty-one
        /// rows of it are ink above his feet, and reserving all forty-eight was a third of
        /// the box holding nothing. Every sheet stands on the same line — see
        /// `Sprite.footPadding`.
        static let stage: CGFloat = 32 * scale
        static let gap: CGFloat = 8
        static let heading: CGFloat = 11
        /// The swatches, and the scale the faces are drawn at.
        static let swatch: CGFloat = 26
        static let face: CGFloat = 3
    }

    var body: some View {
        ZStack {
            Chrome.ground.ignoresSafeArea()

            VStack(spacing: Sheet.gap) {
                header
                stage
                HStack(alignment: .top, spacing: Sheet.gap) {
                    section("Face") { faces }
                    section("Skin") { skins }
                }
                HStack(alignment: .top, spacing: Sheet.gap) {
                    section("Jersey") { swatches($kit.jersey) }
                    section("Belt & shoes") { swatches($kit.belt) }
                }
                HStack(alignment: .bottom, spacing: Sheet.gap) {
                    section("Number") { number }
                    section("Name") { nameField }
                }
                section("Favourite card") { favourite }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            if pickingFavourite { favouritePicker }
        }
    }

    // MARK: - The man

    private var header: some View {
        HStack {
            ScreenTitle(text: "My Hooper", size: 26, drop: CardPalette.blue)
            Spacer()
            Button(action: onDismiss) {
                Chip(fill: CardPalette.red, stroke: CardPalette.gold,
                     shade: CardPalette.orange, side: 32) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Him, at the size the choices are actually judged at.
    ///
    /// A flat slab, not a `Panel`: the orange drop under one of those is what a *button*
    /// wears, and this is the thing being looked at rather than a thing to press.
    private var stage: some View {
        VStack(spacing: 6) {
            // **The stances, above the man they change.** Off at the bottom of the screen
            // they were a list of words you read and then looked up to check; here the
            // thing being changed is directly under the hand changing it.
            poseStrip

            HStack(alignment: .bottom, spacing: 6) {
                positions
                Spacer(minLength: 0)
                figure
                Spacer(minLength: 0)
                winPoseTick
            }
            .frame(height: Sheet.stage)

            SmallCapsText(text: kit.billing, font: Chrome.display, size: 26, tracking: 1)
                .foregroundStyle(.white)
                .shadow(color: Chrome.shade, radius: 0, x: 4, y: 4)
                .lineLimit(1)
                // A floor, not a licence. At 0.5 a long name came out half the size of a
                // short one, which reads as the name having shrunk rather than fitted.
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: Chrome.radius).fill(CardPalette.blue))
        .overlay(RoundedRectangle(cornerRadius: Chrome.radius)
            .strokeBorder(CardPalette.gold, lineWidth: Chrome.stroke))
    }

    /// Him, standing on the floor of the box.
    ///
    /// Bottom-aligned and pushed down by whatever empty rows his sheet leaves under his
    /// feet, so a 48-frame and a 32-frame put a man on the same line. What runs off the
    /// top of the box is the sheet's own empty rows.
    private var figure: some View {
        HooperPortrait(pose: pose, kit: kit, scale: Sheet.scale, castsShadow: true)
            .offset(y: pose.sprite.footPadding * Sheet.scale)
            .frame(height: Sheet.stage, alignment: .bottom)
            .clipped()
    }

    /// The stances, as a row you push along.
    private var poseStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(Kit.Pose.offered) { option in
                    let on = option == pose
                    SmallCapsText(text: option.title, font: Chrome.display, size: 14,
                                  tracking: 0.5)
                        .foregroundStyle(on ? CardPalette.navy : .white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(on ? CardPalette.gold
                                                      : CardPalette.navy.opacity(0.55)))
                        .onTapGesture { pose = option }
                }
            }
            .padding(.horizontal, 10)
        }
        .animation(.easeOut(duration: 0.18), value: pose)
    }

    /// Where he plays, stacked down the empty side of the box.
    private var positions: some View {
        VStack(spacing: 3) {
            ForEach(Kit.Position.allCases) { spot in
                let on = spot == kit.position
                SmallCapsText(text: spot.rawValue, font: Chrome.display, size: 13,
                              tracking: 0.5)
                    .foregroundStyle(on ? CardPalette.navy : .white.opacity(0.75))
                    .frame(width: 34, height: 20)
                    .background(RoundedRectangle(cornerRadius: 5)
                        .fill(on ? CardPalette.gold : CardPalette.navy.opacity(0.55)))
                    .onTapGesture { kit.position = spot }
            }
        }
        .padding(.leading, 10)
        .animation(.easeOut(duration: 0.18), value: kit.position)
    }

    /// **Whether he can be caught standing in this one.**
    ///
    /// Ticking is the whole of how a win pose is chosen — there is no second list to keep
    /// in step with this one. None ticked is every one of them, which is what somebody who
    /// has never opened this screen means as much as somebody who has.
    @ViewBuilder private var winPoseTick: some View {
        if pose.canWin {
            let on = kit.winPoses.contains(pose.rawValue)
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(on ? CardPalette.gold : .clear)
                    .frame(width: 22, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(on ? CardPalette.gold : .white.opacity(0.7),
                                      lineWidth: 2))
                    .overlay {
                        if on {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(CardPalette.navy)
                        }
                    }
                SmallCapsText(text: "Win Pose", font: Chrome.display, size: 11,
                              tracking: 0.5)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 58)
            .contentShape(Rectangle())
            .onTapGesture { kit.toggleWinPose(pose) }
            .padding(.trailing, 10)
            .animation(.easeOut(duration: 0.18), value: on)
        } else {
            Color.clear.frame(width: 58)
        }
    }


    // MARK: - The choices

    /// The nine heads, wrapped. **No box behind them** — a head on a slab reads as a
    /// button with a face on it; the ring alone says which one is on.
    private var faces: some View {
        wrapped(0..<Sprite.heads.frames, columns: 3) { index in
            let on = index == kit.face
            SpriteAnimation(sprite: .heads, scale: Sheet.face, isPlaying: false,
                            restFrame: index)
                .paletteSwap(PixelPalette.skin(tone: kit.tone))
                .overlay {
                    Circle().strokeBorder(on ? CardPalette.gold : .clear, lineWidth: 3)
                }
                .scaleEffect(on ? 1.1 : 1)
                .onTapGesture { kit.face = index }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: kit.face)
    }

    /// The light half of each pair. A swatch showing both would be asking the player to
    /// pick a shading rule.
    private var skins: some View {
        wrapped(PixelPalette.skinTones.indices, columns: 3) { index in
            disc(PixelPalette.skinTones[index].light, on: index == kit.tone)
                .onTapGesture { kit.tone = index }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: kit.tone)
    }

    private func swatches(_ choice: Binding<Int>) -> some View {
        wrapped(Kit.colours.indices, columns: 4) { index in
            disc(Kit.colours[index].main, on: index == choice.wrappedValue)
                .onTapGesture { choice.wrappedValue = index }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: choice.wrappedValue)
    }

    private func disc(_ colour: Color, on: Bool) -> some View {
        Circle()
            .fill(colour)
            .frame(width: Sheet.swatch, height: Sheet.swatch)
            .overlay {
                Circle().strokeBorder(on ? CardPalette.gold : CardPalette.navy,
                                      lineWidth: on ? 4 : 2)
            }
            .scaleEffect(on ? 1.12 : 1)
    }

    /// A list in a stated number of columns.
    ///
    /// **Counted, not adaptive.** Every one of these lists has a shape it wants — nine
    /// faces are three rows of three, six tones are two of three, twelve colours are three
    /// of four — and an adaptive grid gave whatever the width happened to allow, which
    /// changed with the phone. The counts are known, so they are said.
    private func wrapped<Data: RandomAccessCollection, Item: View>(
        _ data: Data, columns: Int, @ViewBuilder item: @escaping (Data.Element) -> Item
    ) -> some View where Data.Element: Hashable {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: columns),
                  spacing: 5) {
            ForEach(Array(data), id: \.self) { item($0) }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Number and name

    private var number: some View {
        VStack(spacing: 2) {
            SmallCapsText(text: "#\(Kit.numbers[kit.number])", font: Chrome.display,
                          size: 26, tracking: 2)
                .foregroundStyle(.white)
                .shadow(color: CardPalette.blue, radius: 0, x: 3, y: 3)
            SteppedSlider(index: $kit.number, count: Kit.numbers.count) {
                Kit.numbers[$0]
            }
        }
    }

    private var nameField: some View {
        TextField("", text: $kit.name)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .font(.custom(Chrome.display, size: 20))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(CardPalette.navy))
            .overlay(Capsule().strokeBorder(CardPalette.gray, lineWidth: 3))
    }

    // MARK: - Favourite card

    private var met: [CardDescriptor] {
        CardLibrary.all.filter { seen.hasSeen($0.id) }.sorted { $0.name < $1.name }
    }

    private var favourite: some View {
        Button { pickingFavourite = true } label: {
            HStack(spacing: 10) {
                if let id = kit.favourite,
                   let card = CardLibrary.all.first(where: { $0.id == id }) {
                    CardFrontView(descriptor: card, displayWidth: 40)
                    SmallCapsText(text: card.name, font: Chrome.display, size: 18,
                                  tracking: 1)
                        .foregroundStyle(.white)
                } else {
                    SmallCapsText(text: met.isEmpty ? "Play a game first" : "Choose one",
                                  font: Chrome.display, size: 18, tracking: 1)
                        .foregroundStyle(CardPalette.gray)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Chrome.radius)
                .fill(CardPalette.navy))
            .overlay(RoundedRectangle(cornerRadius: Chrome.radius)
                .strokeBorder(CardPalette.gray, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .disabled(met.isEmpty)
    }

    /// Only cards this player has actually met — a favourite you have never seen is a
    /// spoiler, and the gallery is already the place to browse the whole pool.
    private var favouritePicker: some View {
        InspectSheet(title: "Favourite", onDismiss: { pickingFavourite = false }) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)],
                          spacing: 8) {
                    ForEach(met) { card in
                        CardFrontView(descriptor: card, displayWidth: 64)
                            .overlay {
                                if kit.favourite == card.id {
                                    RoundedRectangle(cornerRadius: 64 * CardLayout.cornerFraction,
                                                     style: .continuous)
                                        .strokeBorder(CardPalette.gold, lineWidth: 4)
                                }
                            }
                            .onTapGesture {
                                kit.favourite = card.id
                                pickingFavourite = false
                            }
                    }
                }
            }
            .frame(maxHeight: 340)
        }
    }

    // MARK: - Chrome

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SmallCapsText(text: title, font: Chrome.display, size: Sheet.heading,
                          tracking: 1.2)
                .foregroundStyle(CardPalette.gray)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("My Hooper") { HooperView() }
#endif

/// One pose, drawn as a portrait.
///
/// Not `PlayerFigure`: that one is a man on a court, with a ball in his hands only while
/// he is holding one and a warp he leaves by. This is him standing still to be looked at
/// — on his own screen, and on the results card.
///
/// **The face is added, never painted over.** Every sheet is drawn faceless, so what
/// goes on is the eyes and nothing else — where each one sits is `MarkTuning`'s answer,
/// placed by hand against the drawing rather than worked out from it.
struct HooperPortrait: View {
    let pose: Kit.Pose
    /// Whose face and colours. Nil for anybody but the player, who wears their sheet.
    var kit: HooperKit?
    /// Only read when there is no kit — the sideline figure falls back to a seat's
    /// colours the way it does on the court.
    var seat: Seat = GameRules.localSeat
    var scale: CGFloat = Theme.Figure.playerScale
    /// Whether he stands on anything. Off on the results card, where the men are cut out
    /// against black and a shadow would be a floor nobody drew.
    var castsShadow = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if castsShadow { SpriteShadow(scale: scale) }
            if pose.turns {
                // **Four views on one clock.** A turn is not a sheet, so it is walked
                // here rather than described by `Pose.sprite` — and the face comes and
                // goes with the view, since only one of the four is looking at you.
                TimelineView(.animation(minimumInterval: 1 / Theme.Figure.turnFPS)) { tick in
                    let step = Int((tick.date.timeIntervalSinceReferenceDate
                                    * Theme.Figure.turnFPS).rounded(.down))
                    let showing = Kit.Pose.turn[step % Kit.Pose.turn.count]
                    figure(showing.view, mirrored: showing.mirrored)
                }
            } else if pose.isSideline {
                // **The sideline figure, held on its first cell.** Its face, its ball and
                // its palette were all settled when he was put on the sideline; asking
                // for it again here is the whole point of it being a view.
                InbounderFigure(seat: seat, holdsBall: true, frozen: true,
                                face: kit?.face ?? 0, scale: scale, swaps: kit?.swaps)
            } else {
                figure(pose, mirrored: false)
            }
        }
    }

    /// One sheet, dressed, with a face on it when it is looking at you.
    @ViewBuilder
    private func figure(_ showing: Kit.Pose, mirrored: Bool) -> some View {
        ZStack {
            SpriteAnimation(sprite: showing.sprite, scale: scale, fps: showing.fps,
                            isPlaying: showing.plays, restFrame: showing.frame)
                // The player's own kit where there is one; otherwise the seat's, the way
                // he is dressed on the floor. Not the sheet's blue — that is the human's
                // colour, and it put every winner in it.
                .paletteSwap(kit?.swaps ?? PlayerLook.shared.kit(for: seat))
            // Every eye in the game is placed by one table — see `MarksOnSheet`.
            if let kit, showing.sprite.face != nil {
                MarksOnSheet(sheet: showing.sprite, face: kit.face, tone: kit.tone,
                            scale: scale, frame: showing.plays ? nil : showing.frame,
                            fps: showing.fps, playing: showing.plays)
            }
        }
        .scaleEffect(x: mirrored ? -1 : 1)
    }

}

/// What the results card catches a winner standing in.
enum Winner {
    /// The pose for one winner.
    ///
    /// **The player's own is theirs to decide.** Whatever they ticked in My Hooper is the
    /// pool; one tick means always that one, none means the whole list — the same freedom
    /// said twice. Everybody else is rolled.
    ///
    /// Taken off a seed the screen holds rather than rolled here, so the man does not
    /// change stance every time the card redraws — and off `place` as well, so a tie is
    /// never the same man standing there twice.
    static func pose(for seat: Seat, at place: Int, from seed: Int) -> Kit.Pose {
        let pool = seat.isLocal ? HooperKit.shared.chosenWinPoses : Kit.Pose.winnable
        guard !pool.isEmpty else { return .gooseneck }
        return pool[(seed &+ place &* 31) % pool.count]
    }
}
