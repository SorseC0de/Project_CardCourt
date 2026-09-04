import SwiftUI
import UIKit

extension Color {
    /// Straight RGB, which is what the shader compares against.
    var shaderComponents: [Float] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Float(r), Float(g), Float(b)]
    }
}

/// One palette entry replaced by another.
struct PaletteSwap: Hashable {
    let from: Color
    let to: Color

    init(_ from: Color, _ to: Color) {
        self.from = from
        self.to = to
    }
}

extension View {
    /// Replaces palette entries in this view's pixels.
    ///
    /// A `colorEffect`, so it runs on the GPU as part of drawing — no second sheet, no
    /// recoloured copies to keep in step with the original.
    func paletteSwap(_ swaps: [PaletteSwap]) -> some View {
        let flat = swaps.flatMap { $0.from.shaderComponents + $0.to.shaderComponents }
        return colorEffect(ShaderLibrary.paletteSwap(.floatArray(flat)))
    }
}

/// Zuphy32 — the palette the pixel art is drawn from, out of CardCourt_Palette.png.
///
/// Names follow Project Stars' Mort vs Zuphy palette wherever an entry is shared, since
/// that palette is Zuphy32 plus Mort's; the eight entries Zuphy32 has that Mort vs Zuphy
/// does not are named in the same style.
enum PixelPalette {
    // Shared with Project Stars, same names.
    static let warmBlack = Color(hex: 0x302C2E)
    static let mocha = Color(hex: 0x472D3C)
    static let coffee = Color(hex: 0x5E3643)
    static let maroon = Color(hex: 0x7A444A)
    static let darkBrown = Color(hex: 0xA05B53)
    static let brown = Color(hex: 0xBF7958)
    static let khaki = Color(hex: 0xEEA160)
    static let cream = Color(hex: 0xF4CCA1)
    static let iron = Color(hex: 0x5A5353)
    static let steel = Color(hex: 0x7D7071)
    static let stone = Color(hex: 0xA0938E)
    static let slate = Color(hex: 0xCFC6B8)
    static let ice = Color(hex: 0xDFF6F5)
    static let blue = Color(hex: 0x3978A8)
    static let midnight = Color(hex: 0x39314B)
    static let dusk = Color(hex: 0x564064)
    static let darkMagenta = Color(hex: 0x8E478C)
    static let sakura = Color(hex: 0xFFAEB6)
    static let gold = Color(hex: 0xF4B41B)
    static let orange = Color(hex: 0xF47E1B)
    static let darkRed = Color(hex: 0xA93B3B)
    static let lavender = Color(hex: 0x827094)
    static let pewter = Color(hex: 0x4F546B)
    static let lime = Color(hex: 0xB6D53C)
    static let green = Color(hex: 0x71AA34)

    // Zuphy32 only — named to match.
    static let indigo = Color(hex: 0x394778)
    static let pine = Color(hex: 0x397B44)
    static let deepTeal = Color(hex: 0x3C5956)
    static let aqua = Color(hex: 0x8AEBF1)
    static let azure = Color(hex: 0x28CCDF)
    static let rose = Color(hex: 0xCD6093)
    static let darkOrange = Color(hex: 0xD26D19)
    static let vermilion = Color(hex: 0xE6482E)

    // What the sheets are drawn with.
    static let skin = brown
    static let skinShade = darkBrown
    /// The two entries a uniform swap replaces. Neither is used by the ball or the skin,
    /// so a recolour cannot touch anything but the clothes.
    static let jersey = blue
    static let jerseyShade = indigo
    static let ball = orange
    static let ballShade = darkOrange

    /// The skin ramps, darkest entry first — the palette's own indices 0 through 6.
    ///
    /// Every side-by-side pair in the warm ramp works as a skin tone, so the options are
    /// the ramp walked two entries at a time: 6+5 down to 1+0. The sheets are drawn at
    /// 4+3, which is why that pair swaps nothing.
    ///
    /// Read off `CardCourt_Palette.png` rather than from this file's declaration order,
    /// which is *not* the same thing. Starting the ramp at `warmBlack` shifted every pair
    /// by one: it dropped the lightest tone and invented a darkest one shaded with
    /// palette index 11 — a grey, and no part of the skin ramp.
    static let skinRamp: [Color] = [
        mocha, coffee, maroon, darkBrown, brown, khaki, cream,
    ]

    /// The pairs, lightest first. Index into this, not into the ramp.
    static let skinTones: [(light: Color, dark: Color)] = (1..<skinRamp.count)
        .reversed()
        .map { (light: skinRamp[$0], dark: skinRamp[$0 - 1]) }

    /// Where the sheets already sit: brown over darkBrown, the ramp's 4+3, which is the
    /// third pair counting down from the lightest.
    static let drawnSkinTone = 2

    /// The third skin colour, which only the defender sheets carry: one more step down
    /// the ramp than the shade. Sheets without it are unaffected — a swap whose colour is
    /// not in the picture does nothing.
    static let skinDeepShade = maroon

    static func skin(tone: Int) -> [PaletteSwap] {
        guard let pair = skinTones[safe: tone], tone != drawnSkinTone else { return [] }
        // Where `pair.light` sits in the ramp. The deep tone is two below it, and the
        // darkest skin has nothing two below — so it takes warmBlack, which is where the
        // ramp was heading anyway.
        let top = skinRamp.count - 1 - tone
        let deep = top >= 2 ? skinRamp[top - 2] : warmBlack
        return [PaletteSwap(skin, pair.light),
                PaletteSwap(skinShade, pair.dark),
                PaletteSwap(skinDeepShade, deep)]
    }

    /// The uniform each seat wears. The human keeps the sheet's own blue, so their swap
    /// is empty and costs nothing — which is also the seat on screen the most.
    static func uniform(for seat: Seat) -> [PaletteSwap] {
        switch seat {
        case .south: return []
        // Each pair is a real ramp in Zuphy32 — same hue, darker. Gold and dusk were
        // not: gold's only darker neighbour is an orange, and dusk is a grey-violet.
        // Zuphy32 26 and 27. Not red — the defenders a Clamp puts on the floor are.
        case .north: return swap(to: gold, shade: orange)
        case .east:  return swap(to: green, shade: pine)
        case .west:  return swap(to: rose, shade: darkMagenta)
        }
    }

    /// The darker half of what a seat wears. What a name is dropped in, so the label
    /// belongs to the player rather than to the court.
    static func shade(for seat: Seat) -> Color {
        switch seat {
        case .south: return jerseyShade
        case .north: return orange
        case .east:  return pine
        case .west:  return darkMagenta
        }
    }

    /// What a defender wears. Red, whoever put him there — a Clamp is not that player's
    /// teammate arriving, it is the defence.
    static let defenderUniform: [PaletteSwap] = swap(to: vermilion, shade: darkRed)

    private static func swap(to body: Color, shade: Color) -> [PaletteSwap] {
        [PaletteSwap(jersey, body), PaletteSwap(jerseyShade, shade)]
    }

    /// A kit the player has chosen, rather than one a seat comes with.
    static func kit(_ pair: Kit.Pair) -> [PaletteSwap] {
        swap(to: pair.main, shade: pair.shade)
    }

    /// The belt — **and the shoes.**
    ///
    /// Measured off `Player_front`: `slate` and `stone` appear on row 20, which is the
    /// waist, and again on rows 26–27, which are the feet. One pair paints both, so
    /// choosing a belt colour chooses a trim colour. Splitting them needs a third pair in
    /// the art, not another swap here.
    static let trim = slate
    static let trimShade = stone

    static func trim(_ pair: Kit.Pair) -> [PaletteSwap] {
        [PaletteSwap(trim, pair.main), PaletteSwap(trimShade, pair.shade)]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Array {
    /// Out-of-range reads back nil rather than trapping, so a stored appearance from an
    /// older build cannot crash a match.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
