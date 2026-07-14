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
    /// The theme's own accent. Used when the accent picker is set to "Theme" (its default), so
    /// each ported theme reads with its native accent instead of one global hue.
    let accent: Token
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
        accent: Token(lightHex: 0xC88422, darkHex: 0xE8A642),
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
        accent: Token(lightHex: 0x268BD2, darkHex: 0x2AA198),
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
        accent: Token(lightHex: 0x0050CC, darkHex: 0x4499FF),
        diffAddBg: Token(lightHex: 0x007A1B, darkHex: 0x3DE858, lightOpacity: 0.20, darkOpacity: 0.15),
        diffAddText: Token(lightHex: 0x007A1B, darkHex: 0x3DE858),
        diffRemoveBg: Token(lightHex: 0xCC0000, darkHex: 0xFF4444, lightOpacity: 0.20, darkOpacity: 0.15),
        diffRemoveText: Token(lightHex: 0xCC0000, darkHex: 0xFF4444)
    )

    /// Builds a palette from a7t/chat's flat 8-color theme spec (web/src/lib/themes.ts). Those
    /// themes are single-appearance, so each color drives BOTH the light and dark slot — the theme
    /// looks identical regardless of the OS appearance, matching the source. `dark` only selects
    /// the semantic (success/error/…) and diff hues, which a7t/chat's spec doesn't define.
    static func chat(
        dark: Bool,
        bg: UInt,
        surface: UInt,
        surface2: UInt,
        border: UInt,
        text: UInt,
        muted: UInt,
        accent: UInt
    ) -> ThemePalette {
        func t(_ hex: UInt, _ opacity: Double = 1) -> Token {
            Token(lightHex: hex, darkHex: hex, lightOpacity: opacity, darkOpacity: opacity)
        }
        let green: UInt = dark ? 0x32D74B : 0x1F8A36
        let red: UInt = dark ? 0xFF453A : 0xC22A21
        let blue: UInt = dark ? 0x0A84FF : 0x005ECF
        let orange: UInt = dark ? 0xFF9F0A : 0xB86A00
        let purple: UInt = dark ? 0xAF52DE : 0x7A3FB5
        let diffOpacity: Double = dark ? 0.12 : 0.16
        return ThemePalette(
            bgApp: t(bg),
            bgSidebar: t(surface),
            bgCard: t(surface),
            bgCardHover: t(surface2),
            bgElevated: t(surface2),
            bgCode: t(dark ? bg : surface2),
            textPrimary: t(text),
            textSecondary: t(muted),
            textTertiary: t(muted, 0.7),
            border: t(border),
            borderSubtle: t(border, 0.5),
            borderEmphasis: t(border),
            green: t(green),
            red: t(red),
            blue: t(blue),
            orange: t(orange),
            purple: t(purple),
            teal: t(accent),
            accent: t(accent),
            diffAddBg: Token(lightHex: green, darkHex: green, lightOpacity: diffOpacity, darkOpacity: diffOpacity),
            diffAddText: t(green),
            diffRemoveBg: Token(lightHex: red, darkHex: red, lightOpacity: diffOpacity, darkOpacity: diffOpacity),
            diffRemoveText: t(red)
        )
    }
}

enum ColorTheme: String, CaseIterable, Sendable {
    // Poirot's own (appearance-adaptive)
    case `default`
    case solarized
    case highContrast
    // a7t.ai brand (ported from a7t/chat)
    case charcoal
    case tealNight
    case white
    case pastel
    case greenTheme
    // Classic (a7t/chat's names)
    case nightshade
    case fjord
    case fjordLight
    case harbor
    case mocha
    case rosewood
    case ember
    case parchment
    case deepSea
    case daybreak
    case citrus
    case evergreen

    var label: String {
        switch self {
        case .default: "Default"
        case .solarized: "Solarized"
        case .highContrast: "High Contrast"
        case .charcoal: "Charcoal"
        case .tealNight: "Teal Night"
        case .white: "White"
        case .pastel: "Pastel"
        case .greenTheme: "Green"
        case .nightshade: "Nightshade"
        case .fjord: "Fjord"
        case .fjordLight: "Fjord Light"
        case .harbor: "Harbor"
        case .mocha: "Mocha"
        case .rosewood: "Rosewood"
        case .ember: "Ember"
        case .parchment: "Parchment"
        case .deepSea: "Deep Sea"
        case .daybreak: "Daybreak"
        case .citrus: "Citrus"
        case .evergreen: "Evergreen"
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    var palette: ThemePalette {
        // swiftlint:disable multiline_arguments
        switch self {
        case .default: .default
        case .solarized: .solarized
        case .highContrast: .highContrast
        case .charcoal:
            .chat(dark: true, bg: 0x101012, surface: 0x19191C, surface2: 0x212126,
                  border: 0x2B2B30, text: 0xECECEC, muted: 0x9B9BA2, accent: 0x2D9B9B)
        case .tealNight:
            .chat(dark: true, bg: 0x0B3838, surface: 0x0F4444, surface2: 0x135050,
                  border: 0x1F6B6B, text: 0xD7ECEC, muted: 0x7FCDCD, accent: 0x7FCDCD)
        case .white:
            .chat(dark: false, bg: 0xFFFFFF, surface: 0xF5F4F1, surface2: 0xECEBE6,
                  border: 0xE3E1DA, text: 0x0A0F0F, muted: 0x4A5454, accent: 0x1F6B6B)
        case .pastel:
            .chat(dark: false, bg: 0xF7F1E8, surface: 0xEFE6D3, surface2: 0xE7DCC4,
                  border: 0xDCCFB4, text: 0x0A0F0F, muted: 0x4A5454, accent: 0x1F6B6B)
        case .greenTheme:
            .chat(dark: false, bg: 0xEEF3EF, surface: 0xE0EBE2, surface2: 0xD3E2D6,
                  border: 0xC5D8C9, text: 0x0A1F17, muted: 0x45615A, accent: 0x1F6B6B)
        case .nightshade:
            .chat(dark: true, bg: 0x282A36, surface: 0x2F3140, surface2: 0x383A4A,
                  border: 0x44475A, text: 0xF8F8F2, muted: 0x8B8FA3, accent: 0xBD93F9)
        case .fjord:
            .chat(dark: true, bg: 0x2E3440, surface: 0x353C4A, surface2: 0x3B4252,
                  border: 0x434C5E, text: 0xECEFF4, muted: 0x8893A8, accent: 0x88C0D0)
        case .fjordLight:
            .chat(dark: false, bg: 0xECEFF4, surface: 0xE5E9F0, surface2: 0xD8DEE9,
                  border: 0xC8D0DE, text: 0x2E3440, muted: 0x4C566A, accent: 0x5E81AC)
        case .harbor:
            .chat(dark: true, bg: 0x1A1B26, surface: 0x1F2335, surface2: 0x24283B,
                  border: 0x2F334D, text: 0xC0CAF5, muted: 0x787C99, accent: 0x7AA2F7)
        case .mocha:
            .chat(dark: true, bg: 0x1E1E2E, surface: 0x242436, surface2: 0x313244,
                  border: 0x45475A, text: 0xCDD6F4, muted: 0x9399B2, accent: 0xCBA6F7)
        case .rosewood:
            .chat(dark: true, bg: 0x191724, surface: 0x1F1D2E, surface2: 0x26233A,
                  border: 0x403D52, text: 0xE0DEF4, muted: 0x908CAA, accent: 0xEBBCBA)
        case .ember:
            .chat(dark: true, bg: 0x282828, surface: 0x32302F, surface2: 0x3C3836,
                  border: 0x504945, text: 0xEBDBB2, muted: 0xA89984, accent: 0xFABD2F)
        case .parchment:
            .chat(dark: false, bg: 0xFBF1C7, surface: 0xF2E5BC, surface2: 0xEBDBB2,
                  border: 0xD5C4A1, text: 0x3C3836, muted: 0x7C6F64, accent: 0xB57614)
        case .deepSea:
            .chat(dark: true, bg: 0x002B36, surface: 0x073642, surface2: 0x0A4250,
                  border: 0x0F4D5C, text: 0x93A1A1, muted: 0x657B83, accent: 0x2AA198)
        case .daybreak:
            .chat(dark: false, bg: 0xFDF6E3, surface: 0xEEE8D5, surface2: 0xE4DDC8,
                  border: 0xD6CFB8, text: 0x586E75, muted: 0x93A1A1, accent: 0x268BD2)
        case .citrus:
            .chat(dark: true, bg: 0x272822, surface: 0x2F302A, surface2: 0x3A3B32,
                  border: 0x49483E, text: 0xF8F8F2, muted: 0x9A9682, accent: 0xA6E22E)
        case .evergreen:
            .chat(dark: true, bg: 0x2D353B, surface: 0x343F44, surface2: 0x3D484D,
                  border: 0x4A555B, text: 0xD3C6AA, muted: 0x859289, accent: 0xA7C080)
        }
        // swiftlint:enable multiline_arguments
    }

    /// Whether the theme is inherently dark or light, or `nil` when it adapts to the OS
    /// appearance (Poirot's original three). Ported a7t/chat themes are fixed-appearance.
    var isDark: Bool? {
        switch self {
        case .default, .solarized, .highContrast: nil
        case .white, .pastel, .greenTheme, .fjordLight, .parchment, .daybreak: false
        default: true
        }
    }

    /// The window appearance this theme drives. `nil` follows the system (adaptive themes), so
    /// the native chrome always matches the theme's colors.
    var appearance: NSAppearance? {
        guard let isDark else { return nil }
        return NSAppearance(named: isDark ? .darkAqua : .aqua)
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

enum PoirotTheme {
    // MARK: - Colors

    enum Colors {
        // Accent follows the active theme (the separate accent picker was removed in favor of
        // themes carrying their own accent).
        static var accent: Color { color(for: palette.accent) }

        static var accentDim: Color {
            let a = palette.accent
            return Color(lightHex: a.lightHex, darkHex: a.darkHex, lightOpacity: 0.20, darkOpacity: 0.15)
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

        // Native, appearance-adaptive label colors. Because the selected theme sets the window
        // appearance (a light theme -> light chrome), these resolve to a readable value on every
        // theme automatically — no per-theme text color to keep in sync, and no baked-color drift.
        static var textPrimary: Color { Color(nsColor: .labelColor) }
        static var textSecondary: Color { Color(nsColor: .secondaryLabelColor) }
        static var textTertiary: Color { Color(nsColor: .tertiaryLabelColor) }

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
