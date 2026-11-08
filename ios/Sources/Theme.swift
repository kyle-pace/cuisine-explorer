// The shared design language (KitchenUI), visible to every file in the app.
@_exported import KitchenUI
import SwiftUI

/// Cuisines' names for the shared KitchenUI tokens, plus the explorer's continent colors.
/// The brand is saffron on aubergine, the globe's colors: `Palette.use(.saffron, neutrals: .aubergine)`.
enum Theme {
    static var ground: Color { Palette.ground }
    static var surface: Color { Palette.surface }
    static var raised: Color { Palette.raised }
    static var ink: Color { Palette.ink }
    static var muted: Color { Palette.muted }
    static var line: Color { Palette.line }
    static var accent: Color { Palette.accent }
    static var onAccent: Color { Palette.onAccent }

    // Continents, as on the globe. Used for marks and map dots, never as text.
    static let chili = Color(hex: 0xE46A3F)      // Africa
    static let tomatillo = Color(hex: 0x94BD5C)  // the Americas
    static let saffron = Color(hex: 0xF0B340)    // Asia
    static let beet = Color(hex: 0xCF5F87)       // Europe
    static let seaglass = Color(hex: 0x55B8AD)   // Oceania
    static let elsewhere = Color(hex: 0xA99FB5)  // beyond borders

    // Atkinson Hyperlegible Next throughout, as on the globe and kylepace.net. (KitchenUI's serif
    // display face is Henwood's brand, not this one.)
    static let title = Font.app(.largeTitle, .heavy)
    static let heading = Font.app(.title3, .bold)
    static let body = Font.app(.body)
    static let bodyLarge = Font.app(19, .regular, relativeTo: .body)
    static let callout = Font.app(.callout)
    static let callout600 = Font.app(.callout, .semibold)
    static let caption = Font.app(.footnote)

    /// Interface motion: short, eased out, and none when Reduce Motion is on
    static func motion(_ reduce: Bool) -> Animation? { reduce ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.24) }
}

extension Palette.Neutrals {
    /// The globe's aubergine at night; warm paper by day (kylepace.net's light tokens).
    /// Ink, body and muted meet WCAG AA on ground and surface in both.
    static let aubergine = Palette.Neutrals(
        ground: Color(light: 0xFBF8F3, dark: 0x1B1424),
        surface: Color(light: 0xFFFFFF, dark: 0x241B2F),
        raised: Color(light: 0xF3EEE6, dark: 0x2E2439),
        ink: Color(light: 0x1B1A1F, dark: 0xEDE6DA),
        body: Color(light: 0x2E2B33, dark: 0xDDD5C9),
        muted: Color(light: 0x5B5862, dark: 0xA99FB5),
        line: Color(light: 0xE6E0D6, dark: 0x4A3F57),
        divider: Color(light: 0xEEE8DE, dark: 0x352B40))
}

extension Palette.Accent {
    /// Saffron: the globe's Asia color in dark; a deep ochre in light so links and buttons pass AA.
    static let saffron = Palette.Accent(
        accent: Color(light: 0x8A5A00, dark: 0xF0B340),
        onAccent: Color(light: 0xFFFFFF, dark: 0x1B1424),
        inverseAccent: Color(light: 0xF0B340, dark: 0x8A5A00))
}

/// A colored dot (cuisines) or rounded square (everything else), as on the globe
struct Mark: View {
    let color: Color
    var square = false
    var size: CGFloat = 10
    var body: some View {
        RoundedRectangle(cornerRadius: square ? 2 : size / 2)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: square ? 2 : size / 2).stroke(Theme.line, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

struct Tag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.caption)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 7).padding(.vertical, 1)
            .overlay(Capsule().stroke(Theme.line))
    }
}

extension Color {
    /// "#e46a3f" from the explorer's data
    init(hexString: String) {
        var v: UInt64 = 0
        Scanner(string: hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
        self.init(hex: UInt32(truncatingIfNeeded: v))
    }
}
