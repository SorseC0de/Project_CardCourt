import SwiftUI

struct LogView: View {
    let lines: [LogLine]
    var showsBackground = true
    /// Off for the overlay style, where the log is decoration rather than a control.
    var isInteractive = true

    /// The end of the log, and the room under the newest line that keeps it out of the
    /// fade. Scrolled to rather than padded — see the body.
    private static let foot = "log-foot"
    private static let footRoom: CGFloat = 42

    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    private var overflow: CGFloat { max(0, contentHeight - viewportHeight) }
    private var isScrollable: Bool { overflow > 1 }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(lines) { line in
                            Text(line.text)
                                .font(.system(size: 10.5, weight: weight(line.kind), design: .monospaced))
                                .foregroundStyle(color(line.kind))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                        // **Where the scroll stops, and why it is a view.** As padding
                        // this room sat outside everything the reader could aim at, so
                        // scrolling to the last line put it on the very edge — the
                        // faintest part of the fade the room is there to clear. A view
                        // can be scrolled to, so the log ends where its content does.
                        Color.clear
                            .frame(height: Self.footRoom)
                            .id(Self.foot)
                    }
                    .padding(.horizontal, 12)
                    .padding(.trailing, isInteractive ? 6 : 0)
                    .padding(.top, 6)
                    .background {
                        // Preferences do not survive the ScrollView here, so read the
                        // geometry directly and publish it after layout settles.
                        GeometryReader { content in
                            let height = content.size.height
                            let offset = -content.frame(in: .named("log")).minY
                            Color.clear
                                .onAppear { contentHeight = height; scrollOffset = offset }
                                .onChange(of: height) { contentHeight = height }
                                .onChange(of: offset) { scrollOffset = offset }
                        }
                    }
                }
                .coordinateSpace(name: "log")
                .scrollDisabled(!isInteractive)
                .onAppear {
                    viewportHeight = geo.size.height
                    proxy.scrollTo(Self.foot, anchor: .bottom)
                }
                .onChange(of: geo.size.height) {
                    viewportHeight = geo.size.height
                    // The band changing height moves the floor the log is standing on.
                    proxy.scrollTo(Self.foot, anchor: .bottom)
                }
                .onChange(of: lines.count) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(Self.foot, anchor: .bottom)
                    }
                }
            }
            .mask(alignment: .bottom) {
                LinearGradient(colors: [.clear, CardPalette.black], startPoint: .bottom, endPoint: .top)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                if isInteractive && isScrollable { indicator(in: geo.size) }
            }
        }
        .background(showsBackground ? Theme.panel : .clear)
    }

    /// Always on while there is anything to scroll, rather than fading like the system one.
    /// The track is what tells you at a glance that there is more log above.
    private func indicator(in size: CGSize) -> some View {
        let trackHeight = size.height - 8
        let thumb = max(16, trackHeight * (size.height / max(contentHeight, 1)))
        let travel = max(0, trackHeight - thumb)
        let progress = overflow > 0 ? min(1, max(0, scrollOffset / overflow)) : 0
        return ZStack(alignment: .top) {
            Capsule()
                .fill(Theme.inkDim.opacity(0.20))
                .frame(width: 4, height: trackHeight)
            Capsule()
                .fill(Theme.inkDim.opacity(0.85))
                .frame(width: 4, height: thumb)
                .offset(y: travel * progress)
                .animation(.easeOut(duration: 0.15), value: progress)
        }
        .offset(x: -4, y: 4)
    }

    private func color(_ kind: LogLine.Kind) -> Color {
        switch kind {
        case .normal:  return Theme.inkDim
        case .score:   return Theme.live
        case .penalty: return Theme.danger
        case .marker:  return Theme.ink
        }
    }

    private func weight(_ kind: LogLine.Kind) -> Font.Weight {
        switch kind {
        case .normal: return .regular
        default:      return .bold
        }
    }
}
