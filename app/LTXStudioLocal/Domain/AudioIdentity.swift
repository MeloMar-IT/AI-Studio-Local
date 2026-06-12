import Foundation

public struct AudioIdentity: Codable, Identifiable, Equatable {
    public var element: ContinuityElement

    public var id: String { element.id }

    public init(element: ContinuityElement) {
        self.element = element
    }

    public init(name: String, promptBlock: String) {
        self.element = ContinuityElement(type: .audio, name: name, promptBlock: promptBlock)
    }

    public mutating func syncElement() {
        // This is a placeholder for any audio-specific fields we might add to ContinuityElement in the future.
        // For now, it just ensures consistency if we were to add extra fields to AudioIdentity.
    }
}

extension AudioIdentity {
    public static var mock: AudioIdentity {
        AudioIdentity(name: "Synthwave Pulse", promptBlock: "Low-frequency synth pulses with rhythmic industrial percussion")
    }
}
