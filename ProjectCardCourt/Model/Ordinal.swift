import Foundation

/// **1st, 2nd, 3rd, 4th** — the number and the letters after it.
enum Ordinal {
    /// The letters, which are the only hard part: eleven, twelve and thirteen take "th"
    /// whatever they end in.
    static func suffix(_ number: Int) -> String {
        if (11...13).contains(number % 100) { return "th" }
        switch number % 10 {
        case 1:  return "st"
        case 2:  return "nd"
        case 3:  return "rd"
        default: return "th"
        }
    }

    /// **For plain text**, where there is no raised run to set them in — the log. Set in
    /// the Unicode superscript letters, which every one of the four needs exists in.
    static func plain(_ number: Int) -> String {
        let raised: [Character: Character] = ["s": "ˢ", "t": "ᵗ", "n": "ⁿ", "d": "ᵈ",
                                              "r": "ʳ", "h": "ʰ"]
        return "\(number)" + String(suffix(number).map { raised[$0] ?? $0 })
    }
}
