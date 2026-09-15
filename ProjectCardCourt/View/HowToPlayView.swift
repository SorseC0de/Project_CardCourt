import SwiftUI

/// **How To Play**: the lessons, and a table to take each one on.
struct HowToPlayView: View {
    var onDismiss: () -> Void

    /// The lesson being taken, and the table it is taken on. Made when one is opened.
    @State private var lesson: Lesson?

    private struct Lesson {
        let controller: GameController
        let director: TutorialDirector
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
            CardPalette.blue.ignoresSafeArea()
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
                ScreenTitle(text: "How To Play", size: 28, drop: CardPalette.navy)
                Spacer()
                ForEach(Tutorials.all) { tutorial in
                    ChunkyButton(title: tutorial.title, fill: CardPalette.gold,
                                 stroke: CardPalette.gold, shade: CardPalette.orange,
                                 size: 26, run: { open(tutorial) })
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
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
