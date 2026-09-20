import SwiftUI

/// **How To Play**: the lessons, and a table to take each one on.
struct HowToPlayView: View {
    var onDismiss: () -> Void

    /// The lesson being taken, and the table it is taken on. Made when one is opened.
    @State private var lesson: Lesson?
    @State private var tuning = CardTextTuning.shared

    private struct Lesson {
        let controller: GameController
        let director: TutorialDirector
    }

    private enum Menu {
        static let card: CGFloat = 60
        static let turn: Double = 14
        /// In from the button's end, and out over its top or bottom edge.
        static let inset: CGFloat = 10
        static let spill: CGFloat = 16
    }

    var body: some View {
        ZStack {
            if let lesson {
                GameView(controller: lesson.controller, onQuit: { close() },
                         tutorial: lesson.director)
                    .id(ObjectIdentifier(lesson.controller))
                    .transition(.opacity)
            } else {
                menu.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: lesson == nil)
    }

    private var menu: some View {
        ZStack {
            CardPalette.navy.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Button(action: onDismiss) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .heavy))
                            SmallCapsText(text: "Back", font: Chrome.display, size: 16)
                        }
                        .foregroundStyle(.white)
                        .shadow(color: CardPalette.navy, radius: 0, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                ScreenTitle(text: "How To Play", size: 84, drop: CardPalette.navy)
                Spacer()
                ForEach(Array(Tutorials.all.enumerated()), id: \.element.id) { index, tutorial in
                    lessonButton(tutorial, cardLeads: index.isMultiple(of: 2))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    /// Printed in its cards' colours, with one of them spilling off an end — the leading
    /// end and the trailing end in turn down the list.
    private func lessonButton(_ tutorial: Tutorial, cardLeads: Bool) -> some View {
        // The skin a card of that face is printed in, so a lesson wears its own cards'
        // paper and ring in whatever theme is out — see `TutorialOverlay`.
        let skin = CardSkin.of(tutorial.face)
        return ChunkyButton(title: tutorial.title, fill: skin.body, stroke: skin.body,
                            shade: skin.ring,
                            size: 26, run: { open(tutorial) })
            .overlay(alignment: cardLeads ? .leading : .trailing) {
                CardFrontView(descriptor: tutorial.blankCard(named: tutorial.cardName),
                              displayWidth: Menu.card)
                    .rotationEffect(.degrees(cardLeads ? -Menu.turn : Menu.turn))
                    .offset(x: cardLeads ? Menu.inset : -Menu.inset,
                            y: cardLeads ? -Menu.spill : Menu.spill)
                    .allowsHitTesting(false)
            }
    }

    private func open(_ tutorial: Tutorial) {
        let controller = GameController.lesson()
        lesson = Lesson(controller: controller,
                        director: TutorialDirector(tutorial: tutorial, controller: controller))
    }

    private func close() {
        lesson?.controller.quit()
        lesson = nil
    }
}
