import Foundation

public struct BrandKit: Codable, Identifiable, Equatable {
    public var element: ContinuityElement

    public var id: String { element.id }

    public init(element: ContinuityElement) {
        self.element = element
    }

    public init(name: String, promptBlock: String) {
        self.element = ContinuityElement(type: .brand, name: name, promptBlock: promptBlock)
    }
}

extension BrandKit {
    public static var mock: BrandKit {
        BrandKit(name: "Tech-Future Branding", promptBlock: "Logo in top right, clean sans-serif lower thirds, cyan accents")
    }
}
