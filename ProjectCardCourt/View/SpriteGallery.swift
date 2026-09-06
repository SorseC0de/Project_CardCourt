import SwiftUI

#if DEBUG
/// **Every sheet the player is drawn from, with the face on it.**
///
/// One place to check the one thing that cannot be checked anywhere else: whether the
/// eyes land where they should, on every sheet, at every frame. The face is composed
/// exactly as the game composes it — `Sprite.face` decides whether it is both eyes, one,
/// or none, and `Sprite.headOrigin` decides where they go — so what is wrong here is
/// wrong in the game.
///
/// Playing rather than posed: a misplacement that only happens on the fourth cell of a
/// run is the kind this is for.
struct SpriteGallery: View {
    var onDismiss: () -> Void = {}

    @State private var kit = HooperKit.shared
    @State private var scale: CGFloat = 5
    @State private var wearsFace = true
    @State private var playing = true
    @State private var grid = true

    /// Every sheet a man is drawn from. The strips that are not figures — the heads and
    /// faces themselves, the ball, the dust — are left out; there is nothing to check.
    private var sheets: [Sprite] {
        Sprite.allCases.filter { !Self.notFigures.contains($0) }
    }

    private static let notFigures: Set<Sprite> = [.heads, .faces, .smoke, .sparkleBurst]

    var body: some View {
        ZStack {
            Chrome.ground.ignoresSafeArea()
            VStack(spacing: 0) {
                bar
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: grid ? 132 : 320),
                                                 spacing: 10)],
                              spacing: 10) {
                        ForEach(sheets, id: \.self) { cell($0) }
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - One sheet

    private func cell(_ sheet: Sprite) -> some View {
        VStack(spacing: 4) {
            ZStack {
                SpriteAnimation(sprite: sheet, scale: scale,
                                fps: Theme.Figure.playerFPS, isPlaying: playing)
                    .paletteSwap(kit.swaps)
                if wearsFace, let build = sheet.face {
                    FaceOnSheet(sheet: sheet, build: build, kit: kit, scale: scale,
                                playing: playing)
                }
            }
            .frame(width: sheet.frameSize * scale, height: sheet.frameSize * scale)
            .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.28)))

            Text(sheet.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(reading(sheet))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(tint(sheet))
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(CardPalette.navy.opacity(0.6)))
    }

    /// What the code says about this sheet, in the words the audit needs.
    private func reading(_ sheet: Sprite) -> String {
        let face: String
        switch sheet.face {
        case .whole:            face = "two eyes"
        case .profile:          face = "one eye"
        case .glancing(let up): face = "glancing \(Int(up))"
        case nil:               face = "no face"
        }
        return "\(sheet.frames)f · \(face)"
    }

    private func tint(_ sheet: Sprite) -> Color {
        sheet.face == nil ? .white.opacity(0.45) : CardPalette.gold
    }

    // MARK: - The bar

    private var bar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                SmallCapsText(text: "Sprites", font: Chrome.display, size: 22, tracking: 1)
                    .foregroundStyle(.white)
                Spacer()
                toggle("face", $wearsFace)
                toggle("play", $playing)
                toggle("grid", $grid)
                Button(action: onDismiss) {
                    Chip(fill: CardPalette.red, stroke: CardPalette.gold,
                         shade: CardPalette.orange, side: 30) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                Text("scale \(Int(scale))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 56, alignment: .leading)
                Slider(value: $scale, in: 2...12, step: 1)
                Text("face \(kit.face)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white)
                Stepper("") { kit.face = (kit.face + 1) % Sprite.faces.frames }
                    onDecrement: { kit.face = (kit.face + Sprite.faces.frames - 1)
                        % Sprite.faces.frames }
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Chrome.ground)
    }

    private func toggle(_ name: String, _ value: Binding<Bool>) -> some View {
        Button { value.wrappedValue.toggle() } label: {
            SmallCapsText(text: name, font: Chrome.display, size: 12, tracking: 0.5)
                .foregroundStyle(value.wrappedValue ? CardPalette.navy : .white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(value.wrappedValue ? CardPalette.gold
                                                              : CardPalette.navy))
        }
        .buttonStyle(.plain)
    }
}

/// The face, composed on one sheet the way the game composes it.
///
/// Its own view so the gallery and the portrait cannot drift: both ask `Sprite.face` what
/// to draw and `Sprite.headOrigin` where, and neither knows anything else about eyes.
struct FaceOnSheet: View {
    let sheet: Sprite
    let build: Kit.FaceBuild
    let kit: HooperKit
    var scale: CGFloat
    var playing = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / Theme.Figure.playerFPS,
                                paused: !playing)) { tick in
            let cell = playing
                ? SpriteAnimation.cell(of: sheet, at: tick.date,
                                       fps: Theme.Figure.playerFPS)
                : 0
            ZStack {
                eye(shift: .zero, cell: cell)
                if let mirror = build.mirror {
                    eye(shift: mirror, cell: cell).scaleEffect(x: -1)
                }
            }
        }
    }

    private func eye(shift: CGPoint, cell: Int) -> some View {
        OnSheet(rect: CGRect(origin: sheet.headOrigin,
                             size: CGSize(width: 8, height: 8)),
                shift: shift, scale: scale) {
            SpriteAnimation(sprite: .faces, scale: scale, isPlaying: false,
                            restFrame: kit.face)
                .paletteSwap(PixelPalette.skin(tone: kit.tone))
        }
    }
}

#Preview("Sprites") { SpriteGallery() }
#endif
