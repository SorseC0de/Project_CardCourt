import SwiftUI

/// Lettering that starts big on the left and falls away to the right.
///
/// The Persona 5 trick: the line is not one size with a slant applied, it is a *ramp* —
/// the first letter is the loudest thing on screen and every letter after it gives a
/// little back. Read left to right that is a voice trailing off, which is why it reads as
/// spoken rather than printed.
///
/// Built a character at a time rather than as one `Text`, because concatenated text can
/// carry per-run colour but not per-run *shadow* — and a word picked out in gold with its
/// own orange drop, inside a white line with a navy one, is the whole reason this exists.
/// Characters sit on a shared baseline, so the tops fall away and the feet stay put.
struct ActionText: View {
    /// A stretch of the line with its own colours. One is the common case.
    struct Run {
        var text: String
        var ink: Color = .white
        var drop: Color = CardPalette.navy

        init(_ text: String, ink: Color = .white, drop: Color = CardPalette.navy) {
            self.text = text
            self.ink = ink
            self.drop = drop
        }
    }

    var runs: [Run]
    var font = Chrome.display
    /// The first character's size. Everything else is a share of it.
    var size: CGFloat
    /// What the last character comes out at, as a share of the first.
    var taper: CGFloat = 0.55
    /// Both as shares of each character's own size, so they taper with it.
    var tracking: CGFloat = 0.02
    var dropShare: CGFloat = 0.10

    init(_ text: String, font: String = Chrome.display, size: CGFloat,
         ink: Color = .white, drop: Color = CardPalette.navy,
         taper: CGFloat = 0.55, tracking: CGFloat = 0.02, dropShare: CGFloat = 0.10) {
        self.runs = [Run(text, ink: ink, drop: drop)]
        self.font = font
        self.size = size
        self.taper = taper
        self.tracking = tracking
        self.dropShare = dropShare
    }

    init(runs: [Run], font: String = Chrome.display, size: CGFloat,
         taper: CGFloat = 0.55, tracking: CGFloat = 0.02, dropShare: CGFloat = 0.10) {
        self.runs = runs
        self.font = font
        self.size = size
        self.taper = taper
        self.tracking = tracking
        self.dropShare = dropShare
    }

    var body: some View {
        let letters = runs.flatMap { run in run.text.map { (character: $0, run: run) } }
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ForEach(letters.indices, id: \.self) { index in
                let along = letters.count > 1
                    ? CGFloat(index) / CGFloat(letters.count - 1) : 0
                let point = size * (1 - (1 - taper) * along)
                Text(String(letters[index].character))
                    .font(.custom(font, size: point))
                    .foregroundStyle(letters[index].run.ink)
                    .shadow(color: letters[index].run.drop, radius: 0,
                            x: point * dropShare, y: point * dropShare)
                    .padding(.trailing, point * tracking)
            }
        }
        .fixedSize()
    }
}

#if DEBUG
#Preview("Action text") {
    VStack(alignment: .leading, spacing: 26) {
        ActionText("Select a Player", size: 54)
        ActionText(runs: [.init("to "),
                           .init("Inbound", ink: CardPalette.gold, drop: CardPalette.orange),
                           .init(" to!")],
                    size: 30)
        ActionText("Crashing the Glass", size: 40, ink: CardPalette.gold,
                    drop: CardPalette.orange, taper: 0.35)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Chrome.ground)
}
#endif
