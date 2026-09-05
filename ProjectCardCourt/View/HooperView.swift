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
        /// Art pixels per point. Whole numbers only — this is pixel art.
        static let scale: CGFloat = 5
        /// Room for the tallest sheet, so the panel does not resize when the pose does.
        static let stage: CGFloat = 48 * scale
        static let gap: CGFloat = 10
        static let heading: CGFloat = 11
        /// The swatches, and the scale the faces are drawn at.
        static let swatch: CGFloat = 28
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
                section("Pose") {
                    SlabPicker(options: Kit.Pose.allCases, choice: $pose) { $0.title }
                }
                section("Position") {
                    SlabPicker(options: Kit.Position.allCases,
                               choice: $kit.position) { $0.rawValue }
                }
                HStack(alignment: .bottom, spacing: Sheet.gap) {
                    section("Number") { number }
                    section("Name") { nameField }
                }
                section("Favourite card") { favourite }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)

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
        VStack(spacing: 4) {
            ZStack {
                SpriteAnimation(sprite: pose.sprite, scale: Sheet.scale,
                                isPlaying: pose.plays)
                    .paletteSwap(kit.swaps)
                // The head rides on the body's shoulders — see `SpriteMetrics`. Only the
                // front pose is drawn face-on, so it is the only one wearing it.
                if pose == .front { head }
            }
            .frame(height: Sheet.stage)

            SmallCapsText(text: kit.billing, font: Chrome.display, size: 30, tracking: 1)
                .foregroundStyle(.white)
                .shadow(color: Chrome.shade, radius: 0, x: 4, y: 4)
                .lineLimit(1)
                // A floor, not a licence. At 0.5 a long name came out half the size of a
                // short one, which reads as the name having shrunk rather than fitted.
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Chrome.radius).fill(CardPalette.blue))
        .overlay(RoundedRectangle(cornerRadius: Chrome.radius)
            .strokeBorder(CardPalette.gold, lineWidth: Chrome.stroke))
    }

    /// One cell of the heads sheet, sat where the body expects it.
    private var head: some View {
        SpriteAnimation(sprite: .heads, scale: Sheet.scale, isPlaying: false,
                        restFrame: kit.face)
            .paletteSwap(PixelPalette.skin(tone: kit.tone))
            .offset(x: (SpriteMetrics.headOrigin.x - 12) * Sheet.scale,
                    y: (SpriteMetrics.headOrigin.y - 12) * Sheet.scale)
    }

    // MARK: - The choices

    /// The nine heads, wrapped. **No box behind them** — a head on a slab reads as a
    /// button with a face on it; the ring alone says which one is on.
    private var faces: some View {
        wrapped(0..<Sprite.heads.frames, side: 8 * Sheet.face) { index in
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
        wrapped(PixelPalette.skinTones.indices, side: Sheet.swatch) { index in
            disc(PixelPalette.skinTones[index].light, on: index == kit.tone)
                .onTapGesture { kit.tone = index }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: kit.tone)
    }

    private func swatches(_ choice: Binding<Int>) -> some View {
        wrapped(Kit.colours.indices, side: Sheet.swatch) { index in
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

    /// A list wrapped into as many rows as it takes.
    ///
    /// **Adaptive, not a fixed count per row.** Six to a row is six discs plus five gaps
    /// wide whatever the column is, and two of those columns side by side came to more
    /// than the screen — so the lists ran off both edges. This asks for as many as fit.
    private func wrapped<Data: RandomAccessCollection, Item: View>(
        _ data: Data, side: CGFloat, @ViewBuilder item: @escaping (Data.Element) -> Item
    ) -> some View where Data.Element: Hashable {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: side), spacing: 6,
                                     alignment: .leading)],
                  alignment: .leading, spacing: 6) {
            ForEach(Array(data), id: \.self) { item($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
