import SwiftUI

extension Font {
    struct App {
        static let title = Font.system(.title, design: .rounded).weight(.bold)
        static let subtitle = Font.system(.title3, design: .rounded).weight(.medium)
        static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
        static let subheadline = Font.system(.subheadline, design: .rounded)
        static let body = Font.system(.body, design: .rounded)
        static let callout = Font.system(.callout, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
        static let footnote = Font.system(.footnote, design: .rounded)

        static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    }
}
