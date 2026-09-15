import SwiftUI

/// **A lesson over the table**: the wash with its holes, what the step says, and the blips
/// for each leg. Taps on the wash move a tap step on; while the player is being asked to
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
        static let wash = 0.66
        static let blip: CGFloat = 10
    }

    private var step: TutorialStep? { director.current }

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
                chrome
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

    @ViewBuilder private func wash(holes: [CGRect]) -> some View {
        let waiting = step?.advance == .tap || director.isFinished
        HoledWash(holes: holes, padding: Layout.holePadding)
            .fill(Color.black.opacity(Layout.wash), style: FillStyle(eoFill: true))
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
                    card(step)
                }
                .frame(width: Layout.bubbleWidth, height: room)
                .position(x: centre, y: room / 2)
            } else if let union {
                // Below it.
                let top = union.maxY + Layout.holePadding + Layout.gap
                let room = max(0, size.height - top)
                VStack(spacing: 0) {
                    card(step)
                    Spacer(minLength: 0)
                }
                .frame(width: Layout.bubbleWidth, height: room)
                .position(x: centre, y: top + room / 2)
            } else {
                card(step)
                    .frame(width: Layout.bubbleWidth)
                    .position(x: size.width / 2, y: size.height / 2)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func card(_ step: TutorialStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CardText(text: step.text, font: CardFont.name(tuning.weight), size: Layout.textSize,
                     ink: .white, highlight: tuning.highlight, face: .pass)
                .fixedSize(horizontal: false, vertical: true)
            if step.advance == .tap {
                Text("Tap to continue")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(CardPalette.gold)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(Layout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Layout.corner, style: .continuous)
            .fill(CardPalette.blue)
            .shadow(color: CardPalette.gold, radius: 0, x: Layout.drop, y: Layout.drop))
    }

    private func farewell(in size: CGSize) -> some View {
        VStack(spacing: 16) {
            CardText(text: director.tutorial.farewell, font: CardFont.name(tuning.weight),
                     size: Layout.textSize + 2, ink: .white, highlight: tuning.highlight,
                     face: .pass)
                .fixedSize(horizontal: false, vertical: true)
            ChunkyButton(title: "Done", fill: CardPalette.gold, stroke: CardPalette.gold,
                         shade: CardPalette.orange, size: 22, run: onExit)
        }
        .padding(Layout.padding + 6)
        .frame(width: Layout.bubbleWidth)
        .background(RoundedRectangle(cornerRadius: Layout.corner, style: .continuous)
            .fill(CardPalette.blue)
            .shadow(color: CardPalette.gold, radius: 0, x: Layout.drop, y: Layout.drop))
        .position(x: size.width / 2, y: size.height / 2)
    }

    /// The leg blips, the leg's name, and the way out.
    private var chrome: some View {
        VStack {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(director.tutorial.legs.indices, id: \.self) { index in
                            Circle()
                                .fill(index <= director.leg || director.isFinished
                                      ? CardPalette.gold : Color.white.opacity(0.3))
                                .frame(width: Layout.blip, height: Layout.blip)
                                .overlay(Circle().stroke(CardPalette.navy, lineWidth: 1.5))
                        }
                    }
                    if !director.isFinished {
                        SmallCapsText(text: director.tutorial.legs[director.leg].title,
                                      font: Chrome.display, size: 16)
                            .foregroundStyle(.white)
                            .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
                    }
                }
                Spacer()
                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(CardPalette.red))
                        .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 64)
            Spacer()
        }
    }

}

/// The screen with rounded holes cut out of it. Filled even-odd, so the holes are clear.
private struct HoledWash: Shape {
    var holes: [CGRect]
    var padding: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        for hole in holes {
            path.addRoundedRect(in: hole.insetBy(dx: -padding, dy: -padding),
                                cornerSize: CGSize(width: 12, height: 12))
        }
        return path
    }
}
