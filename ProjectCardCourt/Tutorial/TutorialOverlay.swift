import SwiftUI

/// **A lesson over the table**: the wash with its holes, what the step says, the leg's name
/// and the way out. Taps on the wash move a tap step on; while the player is being asked to
/// play, the wash lets every touch through to the game underneath.
struct TutorialOverlay: View {
    let director: TutorialDirector
    /// Where each target is drawn, in this overlay's space.
    let rects: [TutorialTarget: CGRect]
    var onExit: () -> Void

    @State private var tuning = CardTextTuning.shared

    private enum Layout {
        static let bubbleWidth: CGFloat = 300
        static let textSize: CGFloat = 16
        static let padding: CGFloat = 14
        static let corner: CGFloat = 14
        static let drop: CGFloat = 4
        static let gap: CGFloat = 18
        static let margin: CGFloat = 16
        static let holePadding: CGFloat = 8
        static let holeCorner: CGFloat = 12
        static let wash = 0.66
        static let blip: CGFloat = 8
        static let blipGap: CGFloat = 6
        /// Between "Tap to continue" and the popover under it.
        static let promptGap: CGFloat = 6
        static let promptSize: CGFloat = 13
        static let title: CGFloat = 16
        static let exitSize: CGFloat = 14
        static let fanCard: CGFloat = 64
        static let fanTurn: Double = 14
        static let fanSpread: CGFloat = 24
    }

    private var step: TutorialStep? { director.current }
    private var face: CardFace { director.tutorial.face }
    /// **The game's own panel, and the lesson's colour under it.** It used to take the
    /// paper a card is printed on, which is cloud — pale, under the white the words are
    /// set in, and nothing else on this screen is printed that way. What carries the
    /// lesson now is the drop and the blips, in the ring its cards wear.
    private var skin: CardSkin { .of(face) }
    private var popoverFill: Color { Theme.panel }
    private var popoverDrop: Color { skin.ring }

    /// A step that waits on the player only shows itself while the player is being asked to
    /// play — a scene or a question on the table is left alone.
    private var isShowing: Bool {
        if director.isFinished { return true }
        guard let step else { return false }
        if step.advance == .tap { return true }
        if case .awaitingMove = director.controller.gate { return true }
        return false
    }

    var body: some View {
        GeometryReader { screen in
            let holes = (step?.focus ?? []).compactMap { rects[$0] }
            ZStack {
                if isShowing {
                    wash(holes: holes)
                    if director.isFinished {
                        farewell(in: screen.size)
                    } else if let step {
                        bubble(step, holes: holes, in: screen.size)
                    }
                }
                legTitle
                exitButton
            }
            .animation(.easeInOut(duration: 0.2), value: isShowing)
            .animation(.easeInOut(duration: 0.2), value: director.step)
            .animation(.easeInOut(duration: 0.2), value: director.leg)
        }
        .ignoresSafeArea()
        .onAppear { director.start() }
        .onChange(of: director.controller.lessonPlays) { director.gameMoved() }
        .onChange(of: director.controller.lessonBallGone) { director.gameMoved() }
        .onChange(of: director.controller.gate) { director.gameMoved() }
    }

    // MARK: Pieces

    /// The holes are punched out of one layer, so two that overlap make one opening
    /// rather than darkening where they cross.
    private func wash(holes: [CGRect]) -> some View {
        let waiting = step?.advance == .tap || director.isFinished
        return Rectangle()
            .fill(Color.black.opacity(Layout.wash))
            .overlay {
                ForEach(Array(holes.enumerated()), id: \.offset) { _, hole in
                    let cut = hole.insetBy(dx: -Layout.holePadding, dy: -Layout.holePadding)
                    RoundedRectangle(cornerRadius: Layout.holeCorner, style: .continuous)
                        .frame(width: cut.width, height: cut.height)
                        .position(x: cut.midX, y: cut.midY)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture { director.tapped() }
            // Asked to play, the whole table is the player's to touch.
            .allowsHitTesting(waiting)
            .transition(.opacity)
    }

    private func bubble(_ step: TutorialStep, holes: [CGRect], in size: CGSize) -> some View {
        let union = holes.dropFirst().reduce(holes.first) { $0?.union($1) }
        let centre = min(max(union?.midX ?? size.width / 2, Layout.bubbleWidth / 2 + Layout.margin),
                         size.width - Layout.bubbleWidth / 2 - Layout.margin)
        return Group {
            if let union, union.minY > size.height * 0.45 {
                // Above what it points at.
                let room = max(0, union.minY - Layout.holePadding - Layout.gap)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    popover(step)
                }
                .frame(width: Layout.bubbleWidth, height: room)
                .position(x: centre, y: room / 2)
            } else if let union {
                // Below it.
                let top = union.maxY + Layout.holePadding + Layout.gap
                let room = max(0, size.height - top)
                VStack(spacing: 0) {
                    popover(step)
                    Spacer(minLength: 0)
                }
                .frame(width: Layout.bubbleWidth, height: room)
                .position(x: centre, y: top + room / 2)
            } else {
                popover(step)
                    .frame(width: Layout.bubbleWidth)
                    .position(x: size.width / 2, y: size.height / 2)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// "Tap to continue" floating over the box, and the box: the words, then the blips.
    private func popover(_ step: TutorialStep) -> some View {
        VStack(spacing: Layout.promptGap) {
            Text("Tap to continue")
                .font(.system(size: Layout.promptSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 0, x: 2, y: 2)
            VStack(spacing: 10) {
                CardText(text: step.text, font: CardFont.name(tuning.weight), size: Layout.textSize,
                         ink: .white, highlight: tuning.highlight, face: face)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                blips
            }
            .padding(Layout.padding)
            .background(box)
        }
    }

    private var box: some View {
        RoundedRectangle(cornerRadius: Layout.corner, style: .continuous)
            .fill(popoverFill)
            .shadow(color: popoverDrop, radius: 0, x: Layout.drop, y: Layout.drop)
    }

    /// One per leg, lit up to the one being taken.
    private var blips: some View {
        HStack(spacing: Layout.blipGap) {
            ForEach(director.tutorial.legs.indices, id: \.self) { index in
                Circle()
                    .fill(index <= director.leg || director.isFinished ? popoverDrop : .black)
                    .frame(width: Layout.blip, height: Layout.blip)
            }
        }
    }

    private func farewell(in size: CGSize) -> some View {
        VStack(spacing: 14) {
            fan
            CardText(text: director.tutorial.farewell, font: CardFont.name(tuning.weight),
                     size: Layout.textSize + 2, ink: .white, highlight: tuning.highlight,
                     face: face)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            ChunkyButton(title: "GOT IT!", fill: CardPalette.gold, stroke: CardPalette.gold,
                         shade: CardPalette.orange, size: 22, run: onExit)
            blips
        }
        .padding(Layout.padding + 6)
        .frame(width: Layout.bubbleWidth)
        .background(box)
        .position(x: size.width / 2, y: size.height / 2)
    }

    /// Three cards of the lesson's type, blank and nameless, fanned from their feet.
    private var fan: some View {
        let card = director.tutorial.blankCard()
        return ZStack {
            ForEach(-1...1, id: \.self) { place in
                CardFrontView(descriptor: card, displayWidth: Layout.fanCard)
                    .rotationEffect(.degrees(Double(place) * Layout.fanTurn), anchor: .bottom)
                    .offset(x: CGFloat(place) * Layout.fanSpread)
            }
        }
        .frame(height: Layout.fanCard / CardMetrics.aspect)
    }

    @ViewBuilder private var legTitle: some View {
        if !director.isFinished {
            VStack {
                HStack {
                    SmallCapsText(text: director.tutorial.legs[director.leg].title,
                                  font: Chrome.display, size: Layout.title)
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.navy, radius: 0, x: 4, y: 4)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 64)
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }

    /// Under the log, where the game keeps its Varena.
    @ViewBuilder private var exitButton: some View {
        if let spot = rects[.exitSpot] {
            Button(action: onExit) {
                SmallCapsText(text: "Exit Tutorial", font: Chrome.display, size: Layout.exitSize)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(CardPalette.red)
                        .shadow(color: CardPalette.gold, radius: 0, x: 3, y: 3))
            }
            .buttonStyle(.plain)
            .fixedSize()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(x: spot.minX, y: spot.minY)
        }
    }
}
