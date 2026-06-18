import Foundation

public struct LocationElement: Codable, Identifiable, Equatable {
    public var element: ContinuityElement

    public var id: String { element.id }

    public init(element: ContinuityElement) {
        self.element = element
    }

    public init(name: String, promptBlock: String) {
        self.element = ContinuityElement(type: .location, name: name, promptBlock: promptBlock)
    }
}

extension LocationElement {
    public static var mock: LocationElement {
        LocationElement(name: "Neon City Alley", promptBlock: "A dark alleyway in a futuristic city with flickering neon signs")
    }
}
