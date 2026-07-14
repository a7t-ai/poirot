import AppKit
import SwiftUI

// MARK: - Color Theme

struct ThemePalette: Sendable, Equatable {
    struct Token: Sendable, Equatable {
        let lightHex: UInt
        let darkHex: UInt
        var lightOpacity: Double = 1.0
        var darkOpacity: Double = 1.0
    }

    let bgApp: Token
    let bgSidebar: Token
    let bgCard: Token
    let bgCardHover: Token
    let bgElevated: Token
    let bgCode: Token
    let textPrimary: Token
    let textSecondary: Token
    let textTertiary: Token
    let border: Token
    let borderSubtle: Token
    let borderEmphasis: Token
    let green: Token
    let red: Token
    let blue: Token
    let orange: Token
    let purple: Token
    let teal: Token
    let diffAddBg: Token
    let diffAddText: Token
    let diffRemoveBg: Token
    let diffRemoveText: Token

    static let `default` = ThemePalette(
        bgApp: Token(lightHex: 0xF3F4F7, darkHex: 0x0D0D0F),
        bgSidebar: Token(lightHex: 0xECEEF3, darkHex: 0x141416),
        bgCard: Token(lightHex: 0xFFFFFF, darkHex: 0x1A1A1E),
        bgCardHover: Token(lightHex: 0xF5F7FB, darkHex: 0x222226),
        bgElevated: Token(lightHex: 0xFCFCFD, darkHex: 0x222226),
        bgCode: Token(lightHex: 0xEEF1F6, darkHex: 0x161618),
        textPrimary: Token(lightHex: 0x15161A, darkHex: 0xF5F5F7),
        textSecondary: Token(lightHex: 0x4E5260, darkHex: 0x8E8E93),
        textTertiary: Token(lightHex: 0x747A89, darkHex: 0x636366),
        border: Token(lightHex: 0x000000, darkHex: 0xFFFFFF, lightOpacity: 0.10, darkOpacity: 0.06),
        borderSubtle: Token(lightHex: 0x000000, darkHex: 0xFFFFFF, lightOpacity: 0.05, darkOpacity: 0.03),
        borderEmphasis: Token(lightHex: 0x000000, darkHex: 0xFFFFFF, lightOpacity: 0.16, darkOpacity: 0.10),
        green: Token(lightHex: 0x1F8A36, darkHex: 0x32D74B),
        red: Token(lightHex: 0xC22A21, darkHex: 0xFF453A),
        blue: Token(lightHex: 0x005ECF, darkHex: 0x0A84FF),
        orange: Token(lightHex: 0xB86A00, darkHex: 0xFF9F0A),
        purple: Token(lightHex: 0x7A3FB5, darkHex: 0xAF52DE),
        teal: Token(lightHex: 0x0F8F85, darkHex: 0x30D5C8),
        diffAddBg: Token(lightHex: 0x1F8A36, darkHex: 0x32D74B, lightOpacity: 0.16, darkOpacity: 0.10),
        diffAddText: Token(lightHex: 0x166A29, darkHex: 0x32D74B),
        diffRemoveBg: Token(lightHex: 0xC22A21, darkHex: 0xFF453A, lightOpacity: 0.16, darkOpacity: 0.10),
        diffRemoveText: Token(lightHex: 0x9B221B, darkHex: 0xFF453A)
    )

    static let solarized = ThemePalette(
        bgApp: Token(lightHex: 0xFDF6E3, darkHex: 0x002B36),
        bgSidebar: Token(lightHex: 0xEEE8D5, darkHex: 0x073642),
        bgCard: Token(lightHex: 0xFDF6E3, darkHex: 0x073642),
        bgCardHover: Token(lightHex: 0xEEE8D5, darkHex: 0x0A4050),
        bgElevated: Token(lightHex: 0xFDF6E3, darkHex: 0x0A4050),
        bgCode: Token(lightHex: 0xEEE8D5, darkHex: 0x002B36),
        textPrimary: Token(lightHex: 0x073642, darkHex: 0x93A1A1),
        textSecondary: Token(lightHex: 0x586E75, darkHex: 0x839496),
        textTertiary: Token(lightHex: 0x93A1A1, darkHex: 0x657B83),
        border: Token(lightHex: 0x073642, darkHex: 0x839496, lightOpacity: 0.12, darkOpacity: 0.08),
        borderSubtle: Token(lightHex: 0x073642, darkHex: 0x839496, lightOpacity: 0.06, darkOpacity: 0.04),
        borderEmphasis: Token(lightHex: 0x073642, darkHex: 0x839496, lightOpacity: 0.20, darkOpacity: 0.14),
        green: Token(lightHex: 0x859900, darkHex: 0x859900),
        red: Token(lightHex: 0xDC322F, darkHex: 0xDC322F),
        blue: Token(lightHex: 0x268BD2, darkHex: 0x268BD2),
        orange: Token(lightHex: 0xCB4B16, darkHex: 0xCB4B16),
        purple: Token(lightHex: 0x6C71C4, darkHex: 0x6C71C4),
        teal: Token(lightHex: 0x2AA198, darkHex: 0x2AA198),
        diffAddBg: Token(lightHex: 0x859900, darkHex: 0x859900, lightOpacity: 0.16, darkOpacity: 0.12),
        diffAddText: Token(lightHex: 0x859900, darkHex: 0x859900),
        diffRemoveBg: Token(lightHex: 0xDC322F, darkHex: 0xDC322F, lightOpacity: 0.16, darkOpacity: 0.12),
        diffRemoveText: Token(lightHex: 0xDC322F, darkHex: 0xDC322F)
    )

    static let highContrast = ThemePalette(
        bgApp: Token(lightHex: 0xFFFFFF, darkHex: 0x000000),
        bgSidebar: Token(lightHex: 0xF0F0F0, darkHex: 0x0A0A0A),
        bgCard: Token(lightHex: 0xFFFFFF, darkHex: 0x111111),
        bgCardHover: Token(lightHex: 0xE8E8E8, darkHex: 0x1A1A1A),
        bgElevated: Token(lightHex: 0xFFFFFF, darkHex: 0x1A1A1A),
        bgCode: Token(lightHex: 0xF0F0F0, darkHex: 0x0A0A0A),
        textPrimary: Token(lightHex: 0x000000, darkHex: 0xFFFFFF),
        textSecondary: Token(lightHex: 0x222222, darkHex: 0xDDDDDD),
        textTertiary: Token(lightHex: 0x444444, darkHex: 0xAAAAAA),
        border: Token(lightHex: 0x000000, darkHex: 0xFFFFFF, lightOpacity: 0.20, darkOpacity: 0.15),
        borderSubtle: Token(lightHex: 0x000000, darkHex: 0xFFFFFF, lightOpacity: 0.12, darkOpacity: 0.08),
        borderEmphasis: Token(lightHex: 0x000000, darkHex: 0xFFFFFF, lightOpacity: 0.30, darkOpacity: 0.25),
        green: Token(lightHex: 0x007A1B, darkHex: 0x3DE858),
        red: Token(lightHex: 0xCC0000, darkHex: 0xFF4444),
        blue: Token(lightHex: 0x0050CC, darkHex: 0x4499FF),
        orange: Token(lightHex: 0xCC6600, darkHex: 0xFFAA22),
        purple: Token(lightHex: 0x6633CC, darkHex: 0xBB77FF),
        teal: Token(lightHex: 0x007777, darkHex: 0x33DDCC),
        diffAddBg: Token(lightHex: 0x007A1B, darkHex: 0x3DE858, lightOpacity: 0.20, darkOpacity: 0.15),
        diffAddText: Token(lightHex: 0x007A1B, darkHex: 0x3DE858),
        diffRemoveBg: Token(lightHex: 0xCC0000, darkHex: 0xFF4444, lightOpacity: 0.20, darkOpacity: 0.15),
        diffRemoveText: Token(lightHex: 0xCC0000, darkHex: 0xFF4444)
    )

    /// Ported from a7t.ai's palette (the a7t/chat brand): the "White" theme drives the light
    /// appearance, "Charcoal" the dark, both on the signature teal accent. a7t/chat couples one
    /// accent per theme; here the teal lives on the `teal` semantic token — pair this with the
    /// "a7t Teal" accent for the full look.
    static let a7t = ThemePalette(
        bgApp: Token(lightHex: 0xFFFFFF, darkHex: 0x101012),
        bgSidebar: Token(lightHex: 0xF5F4F1, darkHex: 0x19191C),
        bgCard: Token(lightHex: 0xF5F4F1, darkHex: 0x19191C),
        bgCardHover: Token(lightHex: 0xECEBE6, darkHex: 0x212126),
        bgElevated: Token(lightHex: 0xECEBE6, darkHex: 0x212126),
        bgCode: Token(lightHex: 0xECEBE6, darkHex: 0x101012),
        textPrimary: Token(lightHex: 0x0A0F0F, darkHex: 0xECECEC),
        textSecondary: Token(lightHex: 0x4A5454, darkHex: 0x9B9BA2),
        textTertiary: Token(lightHex: 0x4A5454, darkHex: 0x9B9BA2, lightOpacity: 0.7, darkOpacity: 0.7),
        border: Token(lightHex: 0xE3E1DA, darkHex: 0x2B2B30),
        borderSubtle: Token(lightHex: 0xE3E1DA, darkHex: 0x2B2B30, lightOpacity: 0.5, darkOpacity: 0.5),
        borderEmphasis: Token(lightHex: 0xD8D5CC, darkHex: 0x3A3A40),
        green: Token(lightHex: 0x1F8A36, darkHex: 0x32D74B),
        red: Token(lightHex: 0xC22A21, darkHex: 0xFF453A),
        blue: Token(lightHex: 0x005ECF, darkHex: 0x0A84FF),
        orange: Token(lightHex: 0xB86A00, darkHex: 0xFF9F0A),
        purple: Token(lightHex: 0x7A3FB5, darkHex: 0xAF52DE),
        teal: Token(lightHex: 0x1F6B6B, darkHex: 0x2D9B9B),
        diffAddBg: Token(lightHex: 0x1F8A36, darkHex: 0x32D74B, lightOpacity: 0.16, darkOpacity: 0.10),
        diffAddText: Token(lightHex: 0x166A29, darkHex: 0x32D74B),
        diffRemoveBg: Token(lightHex: 0xC22A21, darkHex: 0xFF453A, lightOpacity: 0.16, darkOpacity: 0.10),
        diffRemoveText: Token(lightHex: 0x9B221B, darkHex: 0xFF453A)
    )
}

enum ColorTheme: String, CaseIterable, Sendable {
    case `default`
    case solarized
    case highContrast
    case a7t

    var label: String {
        switch self {
        case .default: "Default"
        case .solarized: "Solarized"
        case .highContrast: "High Contrast"
        case .a7t: "a7t"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .default: .default
        case .solarized: .solarized
        case .highContrast: .highContrast
        case .a7t: .a7t
        }
    }
}

enum ColorThemeStorage {
    nonisolated(unsafe) static var current: ColorTheme = {
        if let raw = UserDefaults.standard.string(forKey: "colorTheme"),
           let theme = ColorTheme(rawValue: raw) {
            return theme
        }
        return .default
    }() {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: "colorTheme")
        }
    }
}

// MARK: - Accent Color

enum AccentColor: String, CaseIterable, Sendable {
    case golden
    case blue
    case purple
    case green
    case red
    case teal
    case a7tTeal

    var label: String {
        switch self {
        case .golden: "Golden"
        case .blue: "Blue"
        case .purple: "Purple"
        case .green: "Green"
        case .red: "Red"
        case .teal: "Teal"
        case .a7tTeal: "a7t Teal"
        }
    }

    var lightHex: UInt {
        switch self {
        case .golden: 0xC88422
        case .blue: 0x005ECF
        case .purple: 0x7A3FB5
        case .green: 0x1F8A36
        case .red: 0xC22A21
        case .teal: 0x0F8F85
        case .a7tTeal: 0x1F6B6B
        }
    }

    var darkHex: UInt {
        switch self {
        case .golden: 0xE8A642
        case .blue: 0x0A84FF
        case .purple: 0xAF52DE
        case .green: 0x32D74B
        case .red: 0xFF453A
        case .teal: 0x30D5C8
        case .a7tTeal: 0x2D9B9B
        }
    }

    /// The preview swatch color (uses the dark hex for a vibrant circle)
    var swatchColor: Color {
        Color(hex: darkHex)
    }
}

// MARK: - Accent Color Storage

enum AccentColorStorage {
    nonisolated(unsafe) static var current: AccentColor = {
        if let raw = UserDefaults.standard.string(forKey: "accentColor"),
           let color = AccentColor(rawValue: raw) {
            return color
        }
        return .golden
    }() {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: "accentColor")
        }
    }
}

enum PoirotTheme {
    // MARK: - Colors

    enum Colors {
        static var accent: Color {
            let c = AccentColorStorage.current
            return Color(lightHex: c.lightHex, darkHex: c.darkHex)
        }

        static var accentDim: Color {
            let c = AccentColorStorage.current
            return Color(lightHex: c.lightHex, darkHex: c.darkHex, lightOpacity: 0.20, darkOpacity: 0.15)
        }

        private static func color(for token: ThemePalette.Token) -> Color {
            Color(
                lightHex: token.lightHex,
                darkHex: token.darkHex,
                lightOpacity: token.lightOpacity,
                darkOpacity: token.darkOpacity
            )
        }

        private static var palette: ThemePalette { ColorThemeStorage.current.palette }

        static var bgApp: Color { color(for: palette.bgApp) }
        static var bgSidebar: Color { color(for: palette.bgSidebar) }
        static var bgCard: Color { color(for: palette.bgCard) }
        static var bgCardHover: Color { color(for: palette.bgCardHover) }
        static var bgElevated: Color { color(for: palette.bgElevated) }
        static var bgCode: Color { color(for: palette.bgCode) }

        static var textPrimary: Color { color(for: palette.textPrimary) }
        static var textSecondary: Color { color(for: palette.textSecondary) }
        static var textTertiary: Color { color(for: palette.textTertiary) }

        static var border: Color { color(for: palette.border) }
        static var borderSubtle: Color { color(for: palette.borderSubtle) }
        static var borderEmphasis: Color { color(for: palette.borderEmphasis) }

        static var green: Color { color(for: palette.green) }
        static var red: Color { color(for: palette.red) }
        static var blue: Color { color(for: palette.blue) }
        static var orange: Color { color(for: palette.orange) }
        static var purple: Color { color(for: palette.purple) }
        static var teal: Color { color(for: palette.teal) }

        static var diffAddBg: Color { color(for: palette.diffAddBg) }
        static var diffAddText: Color { color(for: palette.diffAddText) }
        static var diffRemoveBg: Color { color(for: palette.diffRemoveBg) }
        static var diffRemoveText: Color { color(for: palette.diffRemoveText) }
    }

    // MARK: - Typography

    enum Typography {
        nonisolated(unsafe) static var scale: CGFloat = 1.0

        static var heroTitle: Font { .system(size: round(32 * scale), weight: .semibold) }
        static var title: Font { .system(size: round(28 * scale), weight: .semibold) }
        static var heading: Font { .system(size: round(20 * scale), weight: .semibold) }
        static var headingSmall: Font { .system(size: round(18 * scale), weight: .semibold) }
        static var large: Font { .system(size: round(16 * scale), weight: .regular) }
        static var largeSemibold: Font { .system(size: round(16 * scale), weight: .semibold) }
        static var subheading: Font { .system(size: round(15 * scale), weight: .medium) }
        static var body: Font { .system(size: round(14 * scale), weight: .regular) }
        static var bodyMedium: Font { .system(size: round(14 * scale), weight: .medium) }
        static var caption: Font { .system(size: round(13 * scale), weight: .regular) }
        static var captionMedium: Font { .system(size: round(13 * scale), weight: .medium) }
        static var small: Font { .system(size: round(12 * scale), weight: .regular) }
        static var smallBold: Font { .system(size: round(12 * scale), weight: .semibold) }
        static var tiny: Font { .system(size: round(11 * scale), weight: .regular) }
        static var sectionHeader: Font { .system(size: round(11 * scale), weight: .semibold) }
        static var micro: Font { .system(size: round(10 * scale), weight: .regular) }
        static var microMedium: Font { .system(size: round(10 * scale), weight: .medium) }
        static var microSemibold: Font { .system(size: round(10 * scale), weight: .semibold) }
        static var microBold: Font { .system(size: round(10 * scale), weight: .bold) }
        static var nano: Font { .system(size: round(9 * scale), weight: .regular) }
        static var nanoSemibold: Font { .system(size: round(9 * scale), weight: .semibold) }
        static var nanoBold: Font { .system(size: round(9 * scale), weight: .bold) }
        static var pico: Font { .system(size: round(8 * scale), weight: .regular) }
        static var picoSemibold: Font { .system(size: round(8 * scale), weight: .semibold) }
        static var code: Font { .system(size: round(12.5 * scale), weight: .regular, design: .monospaced) }
        static var codeSmall: Font { .system(size: round(11 * scale), weight: .regular, design: .monospaced) }
        static var codeMicro: Font {
            .system(size: round(10 * scale), weight: .semibold, design: .monospaced)
        }

        static var codeNano: Font {
            .system(size: round(9 * scale), weight: .semibold, design: .monospaced)
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Radii

    enum Radius {
        static let xs: CGFloat = 3
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
    }

    // MARK: - Icon Sizes

    enum IconSize {
        static let sm: CGFloat = 20
        static let md: CGFloat = 36
        static let lg: CGFloat = 52
        static let xl: CGFloat = 96
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        let components = Self.rgbComponents(from: hex)
        self.init(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: opacity
        )
    }

    init(lightHex: UInt, darkHex: UInt, lightOpacity: Double = 1.0, darkOpacity: Double = 1.0) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDarkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let selectedHex = isDarkMode ? darkHex : lightHex
            let selectedOpacity = isDarkMode ? darkOpacity : lightOpacity
            let components = Self.rgbComponents(from: selectedHex)
            return NSColor(
                srgbRed: components.red,
                green: components.green,
                blue: components.blue,
                alpha: selectedOpacity
            )
        })
    }

    private static func rgbComponents(from hex: UInt) -> (red: Double, green: Double, blue: Double) {
        (
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
