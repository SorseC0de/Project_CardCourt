import SwiftUI

/// The pieces every menu is built from.
///
/// One vocabulary, so a screen is assembled rather than drawn: a panel, a button, a chip,
/// a tag. The look is the cards' own — a heavy navy outline, a hard shadow with no blur,
/// flat saturated colour, and condensed heavy type — carried off the table and onto the
/// menus, so the two do not read as two different games.
///
/// Every measurement is a share of the piece's own height or corner, so one number changes
/// a whole screen's weight rather than thirty.
enum Chrome {
    /// The dark the menus are cut out of. Navy is the palette's only dark, which is what
    /// decides everything below it.
    static let ground = CardPalette.navy
    /// The outline every piece wears.
    ///
    /// Grey, not navy — the ground *is* navy, and a navy outline on a navy ground is not
    /// an outline. The grey rim is what makes a panel read as a chunk cut out of the dark
    /// rather than a shape that fades off at its edges.
    static let edge = CardPalette.gray
    /// What falls behind a piece standing on another piece. The same navy drop the cards
    /// and the name plates already use.
    static let shade = CardPalette.navy
    /// How thick that outline is. Heavy on purpose — the weight is the style.
    static let stroke: CGFloat = 6
    /// How far the hard shadow falls. No blur — see the cards.
    static let drop: CGFloat = 6
    /// A panel's corner. Fixed rather than proportional, because a list of panels of
    /// different heights has to have one corner between them.
    static let radius: CGFloat = 20
    /// The corner for a piece that knows its own size, as a share of its shorter side.
    /// The cards' own eight per cent.
    static let corner: CGFloat = 0.08
    static let display = "AvenirNextCondensed-Heavy"

    /// A seat's colour, from the six.
    ///
    /// Four saturated colours and four chairs, which is a fit rather than a coincidence —
    /// navy is the ground and grey is the rim, so what is left is exactly one apiece.
    static func color(for seat: Seat) -> Color {
        switch seat {
        case .south: return CardPalette.blue
        case .west:  return CardPalette.gold
        case .north: return CardPalette.orange
        case .east:  return CardPalette.red
        }
    }
}

/// A slab of flat colour with an outline and a hard shadow. The row, the header, the
/// dialog — everything with a body is one of these.
struct Panel<Content: View>: View {
    var fill: Color = CardPalette.blue
    /// The rim, and what falls behind it. A pair, because a stroke and its shadow being
    /// different colours is most of what makes a panel read as a solid thing.
    var stroke: Color = CardPalette.gold
    var shade: Color = CardPalette.orange
    /// Overrides the corner, for a piece that is not a rounded rectangle's usual shape.
    var radius: CGFloat = Chrome.radius
    var drop: CGFloat = Chrome.drop
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius)
                .strokeBorder(stroke, lineWidth: Chrome.stroke))
            .compositingGroup()
            .shadow(color: shade, radius: 0, x: drop, y: drop)
    }
}

/// The chunky pill everything is done with.
struct ChunkyButton: View {
    let title: String
    var fill: Color = CardPalette.gold
    /// The You chair's rim and drop. Every control that has an edge wears this pair, so a
    /// button and the seat you are sitting in are plainly the same kind of object.
    var stroke: Color = CardPalette.gold
    var shade: Color = CardPalette.orange
    var ink: Color = .white
    var size: CGFloat = 22
    var isEnabled = true
    let run: () -> Void

    var body: some View {
        Button(action: run) {
            SmallCapsText(text: title, font: Chrome.display, size: size,
                          tracking: size * 0.06)
                .foregroundStyle(ink)
                // The label carries its own drop, the way the cards' numbers do. It is
                // what keeps heavy type legible on a saturated fill.
                .shadow(color: Chrome.shade, radius: 0, x: 3, y: 3)
                .padding(.horizontal, size)
                .padding(.vertical, size * 0.42)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(fill))
                .overlay(Capsule().strokeBorder(stroke, lineWidth: Chrome.stroke))
                .compositingGroup()
                .shadow(color: shade, radius: 0, x: Chrome.drop, y: Chrome.drop)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

/// A small square holder for one glyph, at the left of a row.
/// A glyph in a fixed square, so a column of them lines up whatever is drawn in each.
///
/// Bare by default — the box was competing with the panel under it and the glyph inside
/// it. Give it a `fill` and it becomes a solid piece, which is what a control wants.
struct Chip<Content: View>: View {
    var fill: Color?
    var stroke: Color?
    var shade: Color?
    var side: CGFloat = 48
    @ViewBuilder var content: Content

    private var radius: CGFloat { side * Chrome.corner * 2 }
    /// Scaled off the chip rather than shared with the panels. A 6-point rim and a
    /// 6-point drop are right on something the size of a row and far too much on
    /// something the size of a glyph.
    private var weight: CGFloat { side * 0.07 }

    var body: some View {
        content
            .frame(width: side, height: side)
            .background {
                if let fill { RoundedRectangle(cornerRadius: radius).fill(fill) }
            }
            .overlay {
                if let stroke {
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(stroke, lineWidth: weight)
                }
            }
            .compositingGroup()
            .shadow(color: shade ?? .clear, radius: 0,
                    x: shade == nil ? 0 : weight, y: shade == nil ? 0 : weight)
    }
}

/// The little tab that sits on a panel's shoulder and says what state it is in.
struct RibbonTag: View {
    let text: String
    var fill: Color = CardPalette.blue
    var ink: Color = CardPalette.navy
    var size: CGFloat = 13

    var body: some View {
        SmallCapsText(text: text, font: Chrome.display, size: size, tracking: size * 0.08)
            .foregroundStyle(ink)
            .padding(.horizontal, size * 0.8)
            .padding(.vertical, size * 0.22)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: 10, topTrailingRadius: 10)
                    .fill(fill))
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: 10, topTrailingRadius: 10)
                    .strokeBorder(Chrome.shade, lineWidth: Chrome.stroke * 0.5))
    }
}

/// A dark capsule with a glyph at the left and a reading at the right — the top-bar piece.
struct StatPill<Glyph: View>: View {
    let reading: String
    var size: CGFloat = 17
    @ViewBuilder var glyph: Glyph

    var body: some View {
        HStack(spacing: size * 0.35) {
            // Unframed: a glyph knows its own size, and the deck wants to be read at a
            // glance rather than matched to the type beside it.
            glyph
            Text(reading)
                .font(.custom(Chrome.display, size: size))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, size * 0.55)
        .padding(.vertical, size * 0.28)
        .background(Capsule().fill(Chrome.ground))
    }
}

/// A screen title. Heavy, condensed, and wearing the same hard drop as everything else.
struct ScreenTitle: View {
    let text: String
    var size: CGFloat = 40
    var drop: Color = CardPalette.orange

    var body: some View {
        SmallCapsText(text: text, font: Chrome.display, size: size, tracking: size * 0.05)
            .foregroundStyle(.white)
            .shadow(color: drop, radius: 0, x: size * 0.12, y: size * 0.12)
    }
}

#if DEBUG
#Preview("Chrome") {
    VStack(spacing: 22) {
        ScreenTitle(text: "Play a table")
        HStack(spacing: 10) {
            StatPill(reading: "234") { DeckGlyph(side: 44) }
            StatPill(reading: "Sorse") {
                Image(systemName: "person.fill").resizable().scaledToFit()
                    .frame(width: 22, height: 22)
            }
        }
        Panel(fill: CardPalette.blue) {
            HStack(spacing: 12) {
                Chip { Image(systemName: "person.fill")
                    .font(.system(size: 30, weight: .heavy)).foregroundStyle(.white) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tanaka").font(.custom(Chrome.display, size: 24)).foregroundStyle(.white)
                    RibbonTag(text: "Ready", fill: CardPalette.gold)
                }
                Spacer()
            }
            .padding(12)
        }
        ChunkyButton(title: "Find players") {}
        ChunkyButton(title: "Leave", fill: CardPalette.red) {}
        ChunkyButton(title: "Waiting", fill: CardPalette.gray, isEnabled: false) {}
    }
    .padding(26)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Chrome.ground)
}
#endif
