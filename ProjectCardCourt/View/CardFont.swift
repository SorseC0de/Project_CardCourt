import CoreText
import Observation
import SwiftUI

/// The face a card's effect text is set in.
///
/// **Bundled rather than borrowed from the system**: a face is on this Mac and not on a
/// phone, and a `.custom` font that is not there falls back silently to the body face —
/// which reads as the text having simply gone wrong.
///
/// Registered in code rather than through `UIAppFonts`, because the target generates its
/// own Info.plist and an array cannot be spelled as an `INFOPLIST_KEY_`.
///
/// **Every case is one file in `Fonts/`, named after it.** The raw value is both the file
/// and the PostScript name — the two agree for all of these — so adding a face is a case,
/// a label, and dropping the file in the folder.
@Observable
final class CardFont {
    static let shared = CardFont()

    /// **The faces being compared.** Four weights of Barlow Semi Condensed and the
    /// narrower plain Condensed, then six others to be judged against them on the card
    /// rather than in a specimen — which is the only place it matters.
    enum Weight: String, CaseIterable, Hashable {
        case semibold = "BarlowSemiCondensed-SemiBold"
        case bold = "BarlowSemiCondensed-Bold"
        case extraBold = "BarlowSemiCondensed-ExtraBold"
        case black = "BarlowSemiCondensed-Black"
        /// The narrower cut. Same drawing, less width, so more fits on a line.
        case condensed = "BarlowCondensed-Bold"
        case president = "AccidentalPresidency"
        case basillion = "Basillion"
        case vera = "BitstreamVeraSansMono-Bold"
        case geoform = "Geoform-Bold"
        case quicksilver = "Quicksilver"
        case simplyMono = "SimplyMono-Bold"

        /// The name to ask for, which is the file's name too.
        var fontName: String { rawValue }
        /// The one file it lives in. OpenType or TrueType, whichever was drawn.
        var file: (name: String, kind: String) {
            (rawValue, self == .geoform ? "otf" : "ttf")
        }
        /// What the bench shows on a chip. Short, because eleven of them share a row.
        var label: String {
            switch self {
            case .semibold:    return "semibold"
            case .bold:        return "bold"
            case .extraBold:   return "extra bold"
            case .black:       return "black"
            case .condensed:   return "narrow bold"
            case .president:   return "president"
            case .basillion:   return "basillion"
            case .vera:        return "vera mono"
            case .geoform:     return "geoform"
            case .quicksilver: return "quicksilver"
            case .simplyMono:  return "simply mono"
            }
        }
        var next: Weight {
            let all = Weight.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }
    }

    var weight: Weight = .bold

    /// The name to hand `Font.custom`. Falls back to the game's own face for a cut that
    /// did not register, so a missing font looks like the old text rather than like
    /// nothing.
    var name: String { CardFont.name(weight) }

    /// The face for a given cut. **Per card type now** — see `CardTextSet.weight` — so
    /// this is asked for a weight rather than for the one global choice.
    ///
    /// **Asked cut by cut**, not all or nothing: one face failing to register used to
    /// take every other face down with it and set the whole deck in the fallback.
    static func name(_ weight: Weight) -> String {
        registered.contains(weight) ? weight.fontName : "AvenirNextCondensed-Bold"
    }

    private static let registered: Set<Weight> = {
        var done: Set<Weight> = []
        for weight in Weight.allCases {
            let file = weight.file
            guard let url = Bundle.main.url(forResource: file.name,
                                            withExtension: file.kind) else { continue }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                done.insert(weight)
            } else {
                // Already registered is not a failure — a preview can run this twice.
                let code = (error?.takeUnretainedValue() as (any Error)?)
                    .map { ($0 as NSError).code } ?? 0
                if code == Int(CTFontManagerError.alreadyRegistered.rawValue) {
                    done.insert(weight)
                }
            }
        }
        return done
    }()
}
