import SwiftUI

/// **Every Variaball beside the ball it puts on the floor**, to catch an off colour: the
/// card, its drawing on its own, the pixel ball, and a man dribbling it. The two swatches
/// pick the pixel ball's colours out of Zuphy32; the text at the bottom is the table as it
/// would be written back into `BallSpriteInks`.
struct BallBench: View {
    @State private var tuning = BallSpriteTuning.shared

    private enum Row {
        static let card: CGFloat = 70
        static let drawing: CGFloat = 54
        static let pixel: CGFloat = 9
        static let figure: CGFloat = 3
        static let swatch: CGFloat = 26
    }

    private var balls: [CardDescriptor] {
        CardLibrary.variaballs.filter { $0.id != CardLibrary.variaball.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(balls, id: \.id) { ball in
                    HStack(spacing: 14) {
                        CardFrontView(descriptor: ball, displayWidth: Row.card)
                        BallView(diameter: Row.drawing)
                        PixelBallView(scale: Row.pixel)
                        PlayerFigure(seat: .south, isHolding: true, scale: Row.figure)
                        VStack(alignment: .leading, spacing: 6) {
                            swatch(ball, "body", \.body)
                            swatch(ball, "light", \.light)
                        }
                    }
                    .environment(\.ballInPlay, ball)
                }
                Text(table)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
            }
            .padding(16)
        }
        .background(Theme.panel)
    }

    private func swatch(_ ball: CardDescriptor, _ label: String,
                        _ ink: WritableKeyPath<(body: Color, light: Color), Color>) -> some View {
        let now = tuning.inks[ball.id]?[keyPath: ink]
        return Menu {
            ForEach(PixelPalette.named, id: \.name) { entry in
                Button(entry.name) { tuning.inks[ball.id]?[keyPath: ink] = entry.colour }
            }
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(now ?? .clear)
                    .frame(width: Row.swatch, height: Row.swatch)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.4)))
                Text("\(label) \(name(of: now))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .disabled(now == nil)
    }

    private func name(of colour: Color?) -> String {
        guard let colour else { return "—" }
        return PixelPalette.named.first { $0.colour == colour }?.name ?? "?"
    }

    private var table: String {
        tuning.inks.keys.sorted().compactMap { id in
            guard let inks = tuning.inks[id] else { return nil }
            return "\"\(id)\": (body: PixelPalette.\(name(of: inks.body)), "
                + "light: PixelPalette.\(name(of: inks.light))),"
        }
        .joined(separator: "\n")
    }
}

#Preview("Ball bench") {
    BallBench()
        .preferredColorScheme(.dark)
}
