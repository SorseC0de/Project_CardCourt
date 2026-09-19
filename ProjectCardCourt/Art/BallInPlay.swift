import SwiftUI

/// **The ball out on the floor is the Variaball in play.** Its own drawing wherever the
/// plain ball is drawn large, and its colours on the pixel ball the players carry.
@MainActor
enum BallInPlay {
    static let plain = "BallVector"

    /// The drawing, when the ball in play has one of its own — cut out of its card icon
    /// without the aura around it by `Tools/icons.py`.
    static func vector(for ball: CardDescriptor?) -> String {
        guard let ball else { return plain }
        let own = "BallInPlay-\(ball.id)"
        return UIImage(named: own) != nil ? own : plain
    }

    /// How big this ball is against the plain one. The drawings carry it already; the
    /// pixel ball is sized by it — see `BallSizes`.
    static func size(for ball: CardDescriptor?) -> CGFloat {
        ball.flatMap { BallSizes.share[$0.id] } ?? 1
    }

    /// Brand New Ball is the plain ball, catching the light the way a Gold Swishbone does.
    static func shines(_ ball: CardDescriptor?) -> Bool {
        ball?.id == CardLibrary.brandNewBall.id
    }

    /// The pixel ball's two colours turned to this ball's. Read off the bench, so a colour
    /// picked there shows everywhere at once — see `BallBench`.
    static func sprite(for ball: CardDescriptor?) -> [PaletteSwap] {
        guard let ball, let inks = BallSpriteTuning.shared.inks[ball.id] else { return [] }
        return [PaletteSwap(PixelPalette.ballShade, inks.body),
                PaletteSwap(PixelPalette.ball, inks.light)]
    }
}

extension EnvironmentValues {
    /// The Variaball in play, for everything that draws the ball. Set by `GameView`.
    @Entry var ballInPlay: CardDescriptor? = nil
}

/// Where `BallBench` holds its picks. Starts from `BallSpriteInks`.
@Observable
@MainActor
final class BallSpriteTuning {
    static let shared = BallSpriteTuning()
    var inks: [String: (body: Color, light: Color)] = BallSpriteInks.byBall
}
