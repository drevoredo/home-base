import SwiftUI

/// Home Base look: dark, technical, orange accent. Same tokens as the web prototype.
extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    static let hbBackground = Color(hex: 0x0A0C10)
    static let hbSurface = Color(hex: 0x12151B)
    static let hbSurface2 = Color(hex: 0x1A1E26)
    static let hbLine = Color(hex: 0x262C36)
    static let hbAccent = Color(hex: 0xEE7F4B)
    static let hbGood = Color(hex: 0x8BD346)
    static let hbWarn = Color(hex: 0xF5C542)
    static let hbBad = Color(hex: 0xFF5A5F)
    static let hbMuted = Color(hex: 0x9AA3B2)

    // chart series, in fixed order
    static let hbBlue = Color(hex: 0x3987E5)
    static let hbGreen = Color(hex: 0x199E70)
    static let hbPink = Color(hex: 0xD55181)
    static let hbAmber = Color(hex: 0xC98500)
    static let hbPurple = Color(hex: 0x9085E9)
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.hbSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.hbLine))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1)
            .foregroundStyle(Color.hbMuted)
    }
}
