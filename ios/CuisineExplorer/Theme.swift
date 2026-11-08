import SwiftUI

/// The explorer's palette (index.html) and type. Atkinson Hyperlegible Next everywhere,
/// scaled with Dynamic Type; falls back to the system font if the files are missing.
enum Theme {
    static let night = Color(hex: "#1b1424")     // aubergine: page
    static let panel = Color(hex: "#241b2f")
    static let raised = Color(hex: "#2e2439")
    static let line = Color(hex: "#4a3f57")
    static let rice = Color(hex: "#ede6da")      // text
    static let muted = Color(hex: "#a99fb5")
    static let saffron = Color(hex: "#f0b340")   // Asia
    static let beet = Color(hex: "#cf5f87")      // Europe
    static let chili = Color(hex: "#e46a3f")     // Africa
    static let tomatillo = Color(hex: "#94bd5c") // the Americas
    static let seaglass = Color(hex: "#55b8ad")  // Oceania

    static func font(_ size: CGFloat, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("AtkinsonHyperlegibleNext-\(weight.rawValue)", size: size, relativeTo: style)
    }
    enum Weight: String { case regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold", extraBold = "ExtraBold", italic = "Italic" }

    static let title = font(34, .extraBold, relativeTo: .largeTitle)
    static let heading = font(21, .bold, relativeTo: .title3)
    static let body = font(17, relativeTo: .body)
    static let bodyLarge = font(19, relativeTo: .body)
    static let callout = font(15, relativeTo: .callout)
    static let callout600 = font(15, .semibold, relativeTo: .callout)
    static let caption = font(13, relativeTo: .caption)

    /// Interface motion: short, eased out, and none when Reduce Motion is on
    static func motion(_ reduce: Bool) -> Animation? { reduce ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.24) }
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

/// Lays children out in rows, wrapping like inline text
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width { y += line + lineSpacing; x = 0; line = 0 }
            x += s.width + spacing; line = max(line, s.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { y += line + lineSpacing; x = bounds.minX; line = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; line = max(line, s.height)
        }
    }
}
