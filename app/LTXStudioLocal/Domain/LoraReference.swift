import Foundation

public struct LoraReference: Codable, Identifiable, Equatable {
    public var element: ContinuityElement

    public var id: String { element.id }

    public init(element: ContinuityElement) {
        self.element = element
    }

    public init(name: String, promptBlock: String) {
        self.element = ContinuityElement(type: .lora, name: name, promptBlock: promptBlock)
    }
}

extension LoraReference {
    public static var mock: LoraReference {
        LoraReference(name: "80s Anime Style", promptBlock: "<lora:anime_80s:0.8> retro anime aesthetic, hand-drawn look")
    }
}
