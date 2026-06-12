import Foundation

public struct CameraPreset: Codable, Identifiable, Equatable {
    public var element: ContinuityElement

    public var id: String { element.id }

    public init(element: ContinuityElement) {
        self.element = element
    }

    public init(name: String, promptBlock: String) {
        self.element = ContinuityElement(type: .camera, name: name, promptBlock: promptBlock)
    }
}

extension CameraPreset {
    public static var mock: CameraPreset {
        CameraPreset(name: "Slow Dolly Zoom", promptBlock: "Slow dolly zoom into the subject, maintain focus on eyes")
    }
}
