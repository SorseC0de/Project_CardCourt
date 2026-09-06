import SwiftUI

/// **The scrolling layout, kept as a backup.** Superseded by `HooperView`, which fits the
/// whole thing on one page — see the note there. Identical in content; the only
/// difference is that this one lets the page run past the bottom of the screen.
///
/// The player's own man: who he is and what he looks like.
///
/// Everything here is appearance except the name and the number, and even those are
/// appearance as far as the rules are concerned — see `HooperKit`, which no part of the
/// model reads. The point of the screen is that the figure at the top of it changes as
/// you change him, so nothing is chosen from a list of words.
struct HooperScrollLayout: View {
    var onDismiss: () -> Void = {}

    @State private var kit = HooperKit.shared
    @State private var seen = SeenCards.shared
    @State private var pose: Kit.Pose = .front
    @State private var pickingFavourite = false

    private enum Stage {
        /// Art pixels per point. Whole numbers only — this is pixel art.
        static let scale: CGFloat = 6
        /// Room for the tallest sheet, so the panel does not resize when the pose does.
        static let height: CGFloat = 48 * scale
    }

    var body: some View {
        ZStack {
            Chrome.ground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 18) {
                        stage
                        section("Pose") {
                            SlabPicker(options: Kit.Pose.offered, choice: $pose) { $0.title }
                        }
                        section("Face") { faces }
                        section("Skin") {
                            // The light half of each pair. A swatch showing both would be
                            // asking the player to pick a shading rule.
                            SwatchPicker(swatches: PixelPalette.skinTones.map(\.light),
                                         choice: $kit.tone)
                        }
                        section("Jersey") {
                            SwatchPicker(swatches: Kit.colours.map(\.main),
                                         choice: $kit.jersey)
                        }
                        section("Belt & shoes") {
                            SwatchPicker(swatches: Kit.colours.map(\.main),
                                         choice: $kit.belt)
                        }
                        section("Position") {
                            SlabPicker(options: Kit.Position.allCases,
                                       choice: $kit.position) { $0.rawValue }
                        }
                        number
                        nameField
                        favourite
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
            }
            .padding(.top, 14)

            if pickingFavourite { favouritePicker }
        }
    }

    // MARK: - The man

    private var header: some View {
        HStack {
            ScreenTitle(text: "My Hooper", size: 28, drop: CardPalette.blue)
            Spacer()
            Button(action: onDismiss) {
                Chip(fill: CardPalette.red, stroke: CardPalette.gold,
                     shade: CardPalette.orange, side: 34) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    /// Him, at the size the choices are actually judged at.
    private var stage: some View {
        Panel(fill: CardPalette.blue) {
            VStack(spacing: 8) {
                ZStack {
                    SpriteAnimation(sprite: pose.sprite, scale: Stage.scale,
                                    isPlaying: pose.plays, restFrame: pose.frame)
                        .paletteSwap(kit.swaps)
                    // The head rides on the body's shoulders — see `SpriteMetrics`. Only
                    // the front pose is drawn face-on, so it is the only one wearing it.
                    if pose == .front { head }
                }
                .frame(height: Stage.height)

                SmallCapsText(text: kit.billing, font: Chrome.display, size: 26,
                              tracking: 1)
                    .foregroundStyle(.white)
                    .shadow(color: Chrome.shade, radius: 0, x: 4, y: 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                SmallCapsText(text: kit.position.title, font: Chrome.display, size: 14,
                              tracking: 1)
                    .foregroundStyle(CardPalette.navy)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }

    /// One cell of the heads sheet, sat where the body expects it.
    private var head: some View {
        SpriteAnimation(sprite: .heads, scale: Stage.scale, isPlaying: false,
                        restFrame: kit.face)
            .paletteSwap(PixelPalette.skin(tone: kit.tone))
            .offset(x: (SpriteMetrics.headOrigin.x - 12) * Stage.scale,
                    y: (SpriteMetrics.headOrigin.y - 12) * Stage.scale)
    }

    private var faces: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<Sprite.heads.frames, id: \.self) { index in
                    let on = index == kit.face
                    SpriteAnimation(sprite: .heads, scale: 4, isPlaying: false,
                                    restFrame: index)
                        .paletteSwap(PixelPalette.skin(tone: kit.tone))
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(on ? CardPalette.blue : CardPalette.black))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(on ? CardPalette.gold : .clear, lineWidth: 3))
                        .onTapGesture { kit.face = index }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: kit.face)
    }

    // MARK: - Number and name

    private var number: some View {
        section("Number") {
            VStack(spacing: 8) {
                SmallCapsText(text: "#\(Kit.numbers[kit.number])", font: Chrome.display,
                              size: 34, tracking: 2)
                    .foregroundStyle(.white)
                    .shadow(color: CardPalette.blue, radius: 0, x: 3, y: 3)
                SteppedSlider(index: $kit.number, count: Kit.numbers.count) {
                    Kit.numbers[$0]
                }
            }
        }
    }

    private var nameField: some View {
        section("Name") {
            TextField("", text: $kit.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.custom(Chrome.display, size: 24))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(CardPalette.navy))
                .overlay(Capsule().strokeBorder(CardPalette.gray, lineWidth: 3))
        }
    }

    // MARK: - Favourite card

    private var met: [CardDescriptor] {
        CardLibrary.all.filter { seen.hasSeen($0.id) }.sorted { $0.name < $1.name }
    }

    private var favourite: some View {
        section("Favourite card") {
            Button { pickingFavourite = true } label: {
                HStack(spacing: 12) {
                    if let id = kit.favourite,
                       let card = CardLibrary.all.first(where: { $0.id == id }) {
                        CardFrontView(descriptor: card, displayWidth: 54)
                        SmallCapsText(text: card.name, font: Chrome.display, size: 20,
                                      tracking: 1)
                            .foregroundStyle(.white)
                    } else {
                        SmallCapsText(text: met.isEmpty ? "Play a game first" : "Choose one",
                                      font: Chrome.display, size: 20, tracking: 1)
                            .foregroundStyle(CardPalette.gray)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: Chrome.radius)
                    .fill(CardPalette.navy))
                .overlay(RoundedRectangle(cornerRadius: Chrome.radius)
                    .strokeBorder(CardPalette.gray, lineWidth: 3))
            }
            .buttonStyle(.plain)
            .disabled(met.isEmpty)
        }
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
        VStack(alignment: .leading, spacing: 6) {
            SheetHeading(text: title)
            content()
        }
    }
}

#if DEBUG
#Preview("My Hooper — scrolling") { HooperScrollLayout() }
#endif
