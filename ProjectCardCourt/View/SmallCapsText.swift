import SwiftUI

/// Small caps drawn by hand.
///
/// `Font.smallCaps()` only works when the face ships the feature, and Avenir Next
/// Condensed does not — which is why every letter came out the same size.
///
/// Built by concatenating one `Text`, not stacking many. An `HStack` of separate `Text`
/// views lets `minimumScaleFactor` shrink each character on its own, so a long name comes
/// out with letters at mismatched sizes that read as random capitalisation. Concatenation
/// keeps the per-character fonts while behaving as a single run for line limits, scaling
/// and the baseline.
struct SmallCapsText: View {
    let text: String
    let font: String
    let size: CGFloat
    /// How big a former lowercase letter is next to a capital.
    var capHeight: CGFloat = 0.75
    var tracking: CGFloat = 0
    /// Off for lettering set against the art, which has to be the size it was drawn at on
    /// every phone rather than follow the reader's text size.
    var scalesWithTextSize = true

    var body: some View {
        text.reduce(Text(verbatim: "")) { running, character in
            let letter = character.isLowercase ? size * capHeight : size
            return running + Text(String(character).uppercased())
                .font(scalesWithTextSize ? .custom(font, size: letter)
                                         : .custom(font, fixedSize: letter))
        }
        .tracking(tracking)
    }
}
