import SwiftUI

extension Color {
    struct App {
        static let accent = Color.accentColor
        static let background = Color(NSColor.windowBackgroundColor)
        static let secondaryBackground = Color(NSColor.controlBackgroundColor)
        static let surface = Color(NSColor.alternatingContentBackgroundColors.first ?? .controlBackgroundColor)

        static let text = Color.primary
        static let secondaryText = Color.secondary

        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        static let border = Color.secondary.opacity(0.2)
        static let shadow = Color.black.opacity(0.1)
        static let cardBackground = Color(NSColor.controlBackgroundColor)
    }
}
