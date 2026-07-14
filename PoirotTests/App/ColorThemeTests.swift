@testable import Poirot
import Testing

@Suite("ColorTheme")
struct ColorThemeTests {
    // MARK: - All Cases

    @Test
    func allCases_leadWithOriginalsThenPortedThemes() {
        #expect(ColorTheme.allCases.count == 20)
        // Poirot's originals lead the list.
        #expect(Array(ColorTheme.allCases.prefix(3)) == [.default, .solarized, .highContrast])
        // A sampling of ported a7t/chat themes are present.
        #expect(ColorTheme.allCases.contains(.charcoal))
        #expect(ColorTheme.allCases.contains(.nightshade))
        #expect(ColorTheme.allCases.contains(.evergreen))
    }

    @Test
    func isDark_marksFixedThemes_andNilForAdaptiveOriginals() {
        #expect(ColorTheme.default.isDark == nil)
        #expect(ColorTheme.solarized.isDark == nil)
        #expect(ColorTheme.charcoal.isDark == true)
        #expect(ColorTheme.nightshade.isDark == true)
        #expect(ColorTheme.white.isDark == false)
        #expect(ColorTheme.pastel.isDark == false)
    }

    // MARK: - Raw Values

    @Test
    func rawValues_matchExpected() {
        #expect(ColorTheme.default.rawValue == "default")
        #expect(ColorTheme.solarized.rawValue == "solarized")
        #expect(ColorTheme.highContrast.rawValue == "highContrast")
    }

    @Test
    func rawValues_initFromString() {
        #expect(ColorTheme(rawValue: "default") == .default)
        #expect(ColorTheme(rawValue: "solarized") == .solarized)
        #expect(ColorTheme(rawValue: "highContrast") == .highContrast)
        #expect(ColorTheme(rawValue: "invalid") == nil)
    }

    // MARK: - Labels

    @Test
    func labels_matchExpected() {
        #expect(ColorTheme.default.label == "Default")
        #expect(ColorTheme.solarized.label == "Solarized")
        #expect(ColorTheme.highContrast.label == "High Contrast")
    }

    // MARK: - Palette Validation

    @Test
    func defaultPalette_matchesOriginalDesignTokens() {
        let p = ThemePalette.default
        #expect(p.bgApp.lightHex == 0xF3F4F7)
        #expect(p.bgApp.darkHex == 0x0D0D0F)
        #expect(p.textPrimary.lightHex == 0x15161A)
        #expect(p.textPrimary.darkHex == 0xF5F5F7)
        #expect(p.border.lightOpacity == 0.10)
        #expect(p.border.darkOpacity == 0.06)
        #expect(p.green.lightHex == 0x1F8A36)
        #expect(p.green.darkHex == 0x32D74B)
    }

    @Test
    func solarizedPalette_usesCanonicalColors() {
        let p = ThemePalette.solarized
        #expect(p.bgApp.darkHex == 0x002B36) // Base03
        #expect(p.bgSidebar.darkHex == 0x073642) // Base02
        #expect(p.bgApp.lightHex == 0xFDF6E3) // Base3
        #expect(p.bgSidebar.lightHex == 0xEEE8D5) // Base2
        #expect(p.green.lightHex == 0x859900)
        #expect(p.red.lightHex == 0xDC322F)
        #expect(p.blue.lightHex == 0x268BD2)
        #expect(p.orange.lightHex == 0xCB4B16)
        #expect(p.purple.lightHex == 0x6C71C4)
        #expect(p.teal.lightHex == 0x2AA198)
    }

    @Test
    func highContrastPalette_usesMaxContrast() {
        let p = ThemePalette.highContrast
        #expect(p.bgApp.lightHex == 0xFFFFFF)
        #expect(p.bgApp.darkHex == 0x000000)
        #expect(p.textPrimary.lightHex == 0x000000)
        #expect(p.textPrimary.darkHex == 0xFFFFFF)
        #expect(p.border.lightOpacity == 0.20)
        #expect(p.border.darkOpacity == 0.15)
        #expect(p.borderEmphasis.lightOpacity == 0.30)
        #expect(p.borderEmphasis.darkOpacity == 0.25)
    }

    @Test
    func allPalettes_haveNonZeroHexValues() {
        for theme in ColorTheme.allCases {
            let p = theme.palette
            #expect(p.bgApp.lightHex > 0 || p.bgApp.darkHex >= 0, "bgApp should have hex values for \(theme.label)")
            #expect(p.textPrimary.lightHex >= 0, "textPrimary should have hex values for \(theme.label)")
            #expect(p.green.lightHex > 0, "green should have non-zero hex for \(theme.label)")
            #expect(p.red.lightHex > 0, "red should have non-zero hex for \(theme.label)")
        }
    }

    // MARK: - Storage

    @Test
    func storage_defaultIsDefault() {
        let saved = ColorThemeStorage.current
        defer { ColorThemeStorage.current = saved }

        ColorThemeStorage.current = .default
        #expect(ColorThemeStorage.current == .default)
    }

    @Test
    func storage_persistsSelection() {
        let saved = ColorThemeStorage.current
        defer { ColorThemeStorage.current = saved }

        ColorThemeStorage.current = .solarized
        #expect(ColorThemeStorage.current == .solarized)

        ColorThemeStorage.current = .highContrast
        #expect(ColorThemeStorage.current == .highContrast)
    }
}
