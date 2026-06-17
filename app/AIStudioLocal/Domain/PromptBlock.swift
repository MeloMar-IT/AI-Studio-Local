import Foundation

public struct PromptBlock: Codable, Identifiable, Equatable {
    public var element: ContinuityElement

    public var id: String { element.id }

    public init(element: ContinuityElement) {
        self.element = element
    }

    public init(name: String, promptBlock: String) {
        self.element = ContinuityElement(type: .promptBlock, name: name, promptBlock: promptBlock)
    }
}

extension PromptBlock {
    public static var mock: PromptBlock {
        PromptBlock(name: "Weather: Rainy Night", promptBlock: "Heavy rain falling, wet surfaces, reflections of street lights")
    }
}
