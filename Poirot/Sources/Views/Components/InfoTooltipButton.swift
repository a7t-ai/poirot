import SwiftUI

/// A small "ⓘ" button that reveals an explanatory popover on click. Used for the inline
/// info affordances across the analytics dashboard (stat cards, section headers).
///
/// Click-to-open (rather than hover `.help`) so the disclosure is reliable and discoverable:
/// a plain `.help` tooltip on a non-interactive image is easy to miss and never fires on tap.
/// The popover text wraps to a fixed-width column instead of truncating to a single line.
struct InfoTooltipButton: View {
    let text: String

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State
    private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .symbolEffect(.bounce, value: reduceMotion ? 0 : (isPresented ? 1 : 0))
        }
        .buttonStyle(.plain)
        .help("More info")
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            Text(text)
                .font(PoirotTheme.Typography.small)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
                .padding(PoirotTheme.Spacing.md)
        }
    }
}
