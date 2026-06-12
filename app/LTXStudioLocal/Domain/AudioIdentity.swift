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
}

extension AudioIdentity {
    public static var mock: AudioIdentity {
        AudioIdentity(name: "Synthwave Pulse", promptBlock: "Low-frequency synth pulses with rhythmic industrial percussion")
    }
}
