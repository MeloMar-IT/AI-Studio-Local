import Foundation

public struct StyleElement: Codable, Identifiable, Equatable {
    public var element: ContinuityElement

    public var id: String { element.id }

    public init(element: ContinuityElement) {
        self.element = element
    }

    public init(name: String, promptBlock: String) {
        self.element = ContinuityElement(type: .style, name: name, promptBlock: promptBlock)
    }
}

extension StyleElement {
    public static var mock: StyleElement {
        StyleElement(name: "Cinematic Noir", promptBlock: "High contrast, deep shadows, 35mm film grain, moody atmosphere")
    }
}
