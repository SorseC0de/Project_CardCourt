import SwiftUI
import UIKit

#if DEBUG
/// **Every eye on every sheet, placed by hand.**
///
/// The one thing that cannot be checked anywhere else: whether the eyes land where they
/// should, on every sheet, at every frame. What is drawn here is what the game draws —
/// both go through `FaceOnSheet` — so a placement fixed here is fixed everywhere.
///
/// Per eye, per frame, per sheet, because that is how the drawing varies. Most sheets
/// want one answer for all their frames, which is what **All frames** is for; the ones
/// where the head turns or bobs get walked a cell at a time.
///
/// Press **Print** when the pass is done: it puts the whole table on the pasteboard as
/// Swift, ready to be pasted in as the baked-in answer.
struct SpriteGallery: View {
    var onDismiss: () -> Void = {}

    @State private var kit = HooperKit.shared
    @State private var eyes = EyeTuning.shared
    @State private var sheet: Sprite = .front
    @State private var frame = 0
    @State private var scale: CGFloat = 10
    @State private var playing = false
    @State private var showsDump = false
    @State private var dump = ""

    /// Every sheet a man is drawn from. The strips that are not figures — the heads and
    /// faces themselves, the dust — are left out; there is nothing to place on them.
    private var sheets: [Sprite] {
        Sprite.allCases.filter { !Self.notFigures.contains($0) }
    }

    private static let notFigures: Set<Sprite> = [.heads, .faces, .smoke, .sparkleBurst]

    var body: some View {
        ZStack {
            Chrome.ground.ignoresSafeArea()
            VStack(spacing: 8) {
                bar
                sheetStrip
                preview
                frameStrip
                controls
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .sheet(isPresented: $showsDump) { dumpSheet }
    }

    // MARK: - The bar

    private var bar: some View {
        HStack(spacing: 8) {
            SmallCapsText(text: "Eyes", font: Chrome.display, size: 20, tracking: 1)
                .foregroundStyle(.white)
            // How much of this sheet is placed, so the pass has an end you can see.
            let done = eyes.progress(sheet)
            Text("\(sheet.rawValue)  \(done.done)/\(done.all)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(done.done == done.all ? CardPalette.gold
                                 : (done.done > 0 ? .white : CardPalette.gray))
            Spacer()
            chip("play", on: playing) { playing.toggle() }
            chip("reset", on: false) { eyes.forget(sheet) }
            chip("print", on: false) {
                dump = eyes.dump
                UIPasteboard.general.string = dump
                showsDump = true
            }
            Button(action: onDismiss) {
                Chip(fill: CardPalette.red, stroke: CardPalette.gold,
                     shade: CardPalette.orange, side: 28) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Which sheet. Gold means somebody has been at it.
    private var sheetStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(sheets, id: \.self) { option in
                    let on = option == sheet
                    Text(option.rawValue.replacingOccurrences(of: "Player_", with: ""))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(on ? CardPalette.navy
                                         : (eyes.isTuned(option) ? CardPalette.gold : .white))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(on ? CardPalette.gold
                                                      : CardPalette.navy))
                        .onTapGesture { sheet = option; frame = 0 }
                }
            }
        }
    }

    // MARK: - Him, large

    private var preview: some View {
        ZStack {
            // A grid at art-pixel pitch, so a placement can be read off rather than
            // squinted at.
            PixelGrid(pitch: scale)
            SpriteAnimation(sprite: sheet, scale: scale, fps: Theme.Figure.playerFPS,
                            isPlaying: playing, restFrame: frame)
                .paletteSwap(kit.swaps)
            FaceOnSheet(sheet: sheet, face: kit.face, tone: kit.tone, scale: scale,
                        frame: playing ? nil : frame, playing: playing)
        }
        .frame(width: sheet.frameSize * scale, height: sheet.frameSize * scale)
        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.35)))
        .frame(maxWidth: .infinity)
    }

    /// Every cell of this sheet, small. Tap one to work on it.
    private var frameStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(0..<sheet.frames, id: \.self) { cell in
                    let on = cell == frame
                    ZStack {
                        SpriteAnimation(sprite: sheet, scale: 2, isPlaying: false,
                                        restFrame: cell)
                            .paletteSwap(kit.swaps)
                        FaceOnSheet(sheet: sheet, face: kit.face, tone: kit.tone,
                                    scale: 2, frame: cell, playing: false)
                    }
                    .frame(width: sheet.frameSize * 2, height: sheet.frameSize * 2)
                    .background(RoundedRectangle(cornerRadius: 4)
                        .fill(on ? CardPalette.gold.opacity(0.35) : .black.opacity(0.3)))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(on ? CardPalette.gold : .clear, lineWidth: 2))
                    .overlay(alignment: .topLeading) {
                        Text("\(cell)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(2)
                    }
                    .onTapGesture { frame = cell; playing = false }
                }
            }
        }
    }

    // MARK: - The dials

    private var controls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(Eye.allCases, id: \.self) { which in eyeBox(which) }
            }
            HStack(spacing: 8) {
                Text("zoom")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white)
                Slider(value: $scale, in: 4...16, step: 1)
                Text("face \(kit.face)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white)
                chip("next", on: false) {
                    kit.face = (kit.face + 1) % Sprite.faces.frames
                }
            }
        }
    }

    /// One eye's answer for this frame: whether it shows, where it goes, and a way to
    /// give the same answer to the whole sheet at once.
    private func eyeBox(_ which: Eye) -> some View {
        let spot = eyes.spot(sheet, frame: frame, eye: which)
        return VStack(spacing: 5) {
            HStack(spacing: 6) {
                SmallCapsText(text: which.title, font: Chrome.display, size: 13,
                              tracking: 0.5)
                    .foregroundStyle(.white)
                Spacer()
                chip(spot.shown ? "on" : "off", on: spot.shown) {
                    var next = spot; next.shown.toggle()
                    eyes.set(next, on: sheet, frame: frame, eye: which)
                }
            }
            HStack(spacing: 4) {
                nudge("←") { move(which, by: CGPoint(x: -1, y: 0)) }
                nudge("→") { move(which, by: CGPoint(x: 1, y: 0)) }
                Text("x \(Int(spot.x))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CardPalette.gold)
                    .frame(width: 34)
            }
            HStack(spacing: 4) {
                nudge("↑") { move(which, by: CGPoint(x: 0, y: -1)) }
                nudge("↓") { move(which, by: CGPoint(x: 0, y: 1)) }
                Text("y \(Int(spot.y))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CardPalette.gold)
                    .frame(width: 34)
            }
            chip("all frames", on: false) { eyes.spread(from: frame, on: sheet, eye: which) }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(CardPalette.navy.opacity(0.7)))
    }

    private func move(_ which: Eye, by step: CGPoint) {
        var spot = eyes.spot(sheet, frame: frame, eye: which)
        spot.x += step.x
        spot.y += step.y
        spot.shown = true
        eyes.set(spot, on: sheet, frame: frame, eye: which)
    }

    private func nudge(_ glyph: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(glyph)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(CardPalette.navy)
                .frame(width: 32, height: 26)
                .background(RoundedRectangle(cornerRadius: 5).fill(CardPalette.gold))
        }
        .buttonStyle(.plain)
    }

    private func chip(_ name: String, on: Bool, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            SmallCapsText(text: name, font: Chrome.display, size: 11, tracking: 0.5)
                .foregroundStyle(on ? CardPalette.navy : .white)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(on ? CardPalette.gold : CardPalette.navy))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Out

    private var dumpSheet: some View {
        ZStack {
            Chrome.ground.ignoresSafeArea()
            VStack(spacing: 10) {
                SmallCapsText(text: "Copied to the clipboard", font: Chrome.display,
                              size: 18, tracking: 1)
                    .foregroundStyle(.white)
                ScrollView {
                    Text(dump)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                ChunkyButton(title: "Done", fill: CardPalette.blue, size: 16) {
                    showsDump = false
                }
            }
            .padding(16)
        }
    }
}

/// A grid at art-pixel pitch, so a placement can be counted rather than guessed.
private struct PixelGrid: View {
    let pitch: CGFloat

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0, through: size.width, by: pitch) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: pitch) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
        }
    }
}

#Preview("Eyes") { SpriteGallery() }
#endif
