import Foundation

public struct CharacterElement: Codable, Identifiable, Equatable {
    public var element: ContinuityElement

    public var id: String { element.id }
    public var name: String {
        get { element.name }
        set { element.name = newValue }
    }

    public init(element: ContinuityElement) {
        self.element = element
    }

    public init(name: String, promptBlock: String) {
        self.element = ContinuityElement(type: .character, name: name, promptBlock: promptBlock)
    }
}

extension CharacterElement {
    public static var mock: CharacterElement {
        CharacterElement(name: "Cyberpunk Nomad", promptBlock: "A rugged nomad wearing neon-lit leather jacket")
    }
}
