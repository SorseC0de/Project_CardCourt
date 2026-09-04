import CoreText
import Observation
import SwiftUI

/// The face a card's effect text is set in, and how heavy it is.
///
/// Barlow Semi Condensed, bundled rather than borrowed from the system: it is on this Mac
/// but not on a phone, and a `.custom` font that is not there falls back silently to the
/// body face — which reads as the text having simply gone wrong.
///
/// Registered in code rather than through `UIAppFonts`, because the target generates its
/// own Info.plist and an array cannot be spelled as an `INFOPLIST_KEY_`.
@Observable
final class CardFont {
    static let shared = CardFont()

    /// The weights being compared, lightest first. Only Barlow Semi Condensed is
    /// installed — the narrower plain Condensed cut is not, so it is not offered.
    enum Weight: String, CaseIterable {
        case semibold = "SemiCondensed-SemiBold"
        case bold = "SemiCondensed-Bold"
        case extraBold = "SemiCondensed-ExtraBold"
        case black = "SemiCondensed-Black"

        var fontName: String { "Barlow\(rawValue)" }
        /// What the bench shows: the part that differs between them.
        var label: String {
            rawValue.replacingOccurrences(of: "SemiCondensed-", with: "")
                .replacingOccurrences(of: "-", with: " ").lowercased()
        }
        var next: Weight {
            let all = Weight.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }
    }

    var weight: Weight = .bold

    /// The name to hand `Font.custom`. Falls back to the game's own face if Barlow did
    /// not register, so a missing font looks like the old text rather than like nothing.
    var name: String { CardFont.registered ? weight.fontName : "AvenirNextCondensed-Bold" }

    private static let registered: Bool = {
        var ok = true
        for weight in Weight.allCases {
            guard let url = Bundle.main.url(forResource: weight.fontName,
                                            withExtension: "ttf") else { ok = false; continue }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already registered is not a failure — a preview can run this twice.
                let code = (error?.takeUnretainedValue() as (any Error)?)
                    .map { ($0 as NSError).code } ?? 0
                if code != Int(CTFontManagerError.alreadyRegistered.rawValue) { ok = false }
            }
        }
        return ok
    }()
}
