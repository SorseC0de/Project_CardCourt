import SwiftUI

/// Every pixel face bundled with the game, registered and named.
///
/// **Found by geometry, not by filename.** A pixel font's glyph corners all land on one
/// coarse grid — that is what makes it one — so the archive was measured rather than
/// searched for the word "pixel", and these are what came back.
///
/// Registered from the bundle at runtime the way `CardFont` does it, so nothing has to be
/// listed in a plist and a face can be added by dropping the file in.
enum PixelFont {
    /// What the picker offers, in the order it offers them. The name shown is the
    /// PostScript name the font reports, read off the file rather than typed here.
    struct Face: Hashable, Identifiable {
        let name: String
        let file: String
        var id: String { name }
        /// Short enough for a chip.
        var label: String {
            name.replacingOccurrences(of: "Regular", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .trimmingCharacters(in: .whitespaces)
        }
    }

    /// The files, by name. Extensions differ, so both are tried.
    private static let files = [
        "7pixelsOfPerfection", "BMarmy", "BMmini", "DraconianPixelsMinimal", "Grand9KPixel",
        "MinimalFont5x7", "Minimum", "Minimum1", "PixeloidMono", "PlanetaryContact",
        "PressStart2P", "RetroGaming", "TeenyTinyPixls", "alagard", "bitlow", "console",
        "dogica", "dogicabold", "dogicapixel", "dogicapixelbold", "pixel-arial-14",
        "re-do", "uni05_53", "uni05_54", "uni05_63", "uni05_64", "upheavtt",
    ]

    /// Registered once, and named by what each file says it is called.
    static let all: [Face] = {
        var faces: [Face] = []
        for file in files {
            var found: URL?
            for ext in ["ttf", "TTF", "otf"] {
                if let url = Bundle.main.url(forResource: file, withExtension: ext) {
                    found = url; break
                }
            }
            guard let url = found else { continue }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Registering twice is what a preview does, and is not a failure.
                let code = (error?.takeUnretainedValue() as (any Error)?)
                    .map { ($0 as NSError).code } ?? 0
                guard code == Int(CTFontManagerError.alreadyRegistered.rawValue) else { continue }
            }
            guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)
                    as? [CTFontDescriptor], let first = descriptors.first else { continue }
            let font = CTFontCreateWithFontDescriptor(first, 12, nil)
            faces.append(Face(name: CTFontCopyPostScriptName(font) as String, file: file))
        }
        return faces.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }()

    /// The one to start on, and what a missing choice falls back to.
    static var fallback: String { all.first?.name ?? "Menlo" }
}
