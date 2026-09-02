import SwiftUI

/// How the log shares space with the court.
enum LogStyle: CaseIterable {
    /// Its own band beneath the court.
    case panel
    /// Court takes the space; the log floats over it, faded out at the top.
    case overlay
    /// No log at all; the court takes the space.
    case hidden

    var next: LogStyle {
        let all = LogStyle.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var symbol: String {
        switch self {
        case .panel:   return "list.bullet.rectangle"
        case .overlay: return "rectangle.bottomthird.inset.filled"
        case .hidden:  return "rectangle"
        }
    }

    var label: String {
        switch self {
        case .panel:   return "Log panel"
        case .overlay: return "Log overlay"
        case .hidden:  return "Log hidden"
        }
    }
}

struct LogView: View {
    let lines: [LogLine]
    var showsBackground = true
    /// Off for the overlay style, where the log is decoration rather than a control.
    var isInteractive = true

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
                    }
                    .padding(.horizontal, 12)
                    .padding(.trailing, isInteractive ? 6 : 0)
                    .padding(.top, 6)
                    // Clears the bottom fade, so the newest line is never the faintest.
                    .padding(.bottom, 14)
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
                    // Switching styles rebuilds this view, so start at the newest line.
                    if let last = lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onChange(of: geo.size.height) { viewportHeight = geo.size.height }
                .onChange(of: lines.count) {
                    guard let last = lines.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
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
