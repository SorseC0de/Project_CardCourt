import SwiftUI

/// **The pixel ball's two colours, per Variaball in play.** `body` takes the sheet's
/// `ballShade`, which is most of the ball, and `light` its `ball`.
///
/// Listed by `Tools/icons.py` for any ball not yet here, off the nearest Zuphy32 entries
/// to the drawing's own body and highlight — and **never rewritten once listed**, so a
/// correction made on `BallBench` stays made.
enum BallSpriteInks {
    static let byBall: [String: (body: Color, light: Color)] = [
        "bagn-ball": (body: PixelPalette.orange, light: PixelPalette.gold),
        "blaze-ball": (body: PixelPalette.vermilion, light: PixelPalette.orange),
        "blight-ball": (body: PixelPalette.midnight, light: PixelPalette.indigo),
        "brick-ball": (body: PixelPalette.darkRed, light: PixelPalette.vermilion),
        "dishcount-ball": (body: PixelPalette.pine, light: PixelPalette.blue),
        "dishtracting-ball": (body: PixelPalette.lavender, light: PixelPalette.ice),
        "foot-ball": (body: PixelPalette.vermilion, light: PixelPalette.midnight),
        "hand-ball": (body: PixelPalette.midnight, light: PixelPalette.vermilion),
        "hero-ball": (body: PixelPalette.blue, light: PixelPalette.vermilion),
        "monster-ball": (body: PixelPalette.darkRed, light: PixelPalette.darkMagenta),
        "recharge-rock": (body: PixelPalette.gold, light: PixelPalette.aqua),
        "snow-ball": (body: PixelPalette.aqua, light: PixelPalette.ice),
    ]
}
