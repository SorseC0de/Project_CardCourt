import SwiftUI

/// The beat a turnover gets, so it lands instead of flashing past in the log.
struct TurnoverCutsceneView: View {
    let scene: TurnoverCutscene

    @State private var expired = false
    @State private var flash = false
    @State private var ballAway = false
    @State private var showCaption = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.94).ignoresSafeArea()

                if case .shotClock = scene.kind {
                    VStack(spacing: 10) {
                        shotClockBoard
                        HoopBackdrop()
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.27)
                }

                VStack(spacing: 8) {
                    PlayerFigure(seat: scene.seat, sprite: .catchBall, scale: 3)
                    Text(scene.seat.playerName.uppercased())
                        .font(.system(size: 12, weight: .heavy)).tracking(1.4)
                        .foregroundStyle(Theme.inkDim)
                }
                .position(x: geo.size.width / 2, y: geo.size.height - 150)

                // Held on a dead clock, or gone entirely.
                if scene.kind != .badReturn || !ballAway {
                    PixelBallView(scale: 4)
                        .position(x: geo.size.width / 2 + (ballAway ? geo.size.width : 34),
                                  y: geo.size.height - 176 - (ballAway ? 120 : 0))
                        .opacity(ballAway ? 0 : 1)
                }

                VStack(spacing: 4) {
                    Text("TURNOVER")
                        .font(.system(size: 13, weight: .black)).tracking(2.4)
                        .foregroundStyle(Theme.danger)
                    Text(caption)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 24)
                }
                .opacity(showCaption ? 1 : 0)
                .scaleEffect(showCaption ? 1 : 0.8)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.56)
            }
            .task { await run() }
        }
    }

    /// The box on the backboard, lighting red as it dies — the NBA tell.
    private var shotClockBoard: some View {
        SevenSegmentClock(value: expired ? 0 : 1, digitSize: CGSize(width: 30, height: 56))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(flash ? Theme.clockRed : Color.white.opacity(0.25),
                                    lineWidth: flash ? 4 : 1.5)
                    }
                    .shadow(color: flash ? Theme.clockRed.opacity(0.9) : .clear, radius: 18)
            }
    }

    private var caption: String {
        switch scene.kind {
        case .shotClock:            return "Shot clock violation"
        case .badReturn:            return "Nobody to give it back to"
        case .whistle(let name):    return name
        }
    }

    private func run() async {
        try? await Task.sleep(for: .seconds(0.55))
        withAnimation(.easeOut(duration: 0.12)) { expired = true; flash = true }
        if scene.kind == .badReturn {
            withAnimation(.easeIn(duration: 0.65)) { ballAway = true }
        }
        try? await Task.sleep(for: .seconds(0.28))
        withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) { showCaption = true }
    }
}
