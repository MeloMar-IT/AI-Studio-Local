import Foundation

public enum SceneMode: String, Codable, CaseIterable {
    case textToVideo = "text-to-video"
    case imageToVideo = "image-to-video"
    case audioToVideo = "audio-to-video"
    case retake
}

public struct SceneResolution: Codable, Equatable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct AttachedContinuityElement: Codable, Equatable {
    public var elementId: String
    public var type: ContinuityElementType

    public init(elementId: String, type: ContinuityElementType) {
        self.elementId = elementId
        self.type = type
    }

    enum CodingKeys: String, CodingKey {
        case elementId = "element_id"
        case type
    }
}

public struct ConsistencyLocks: Codable, Equatable {
    public var character: Bool = false
    public var clothing: Bool = false
    public var location: Bool = false
    public var style: Bool = false
    public var brand: Bool = false
    public var audio: Bool = false
    public var seed: Bool = false
    public var camera: Bool = false

    public init(
        character: Bool = false,
        clothing: Bool = false,
        location: Bool = false,
        style: Bool = false,
        brand: Bool = false,
        audio: Bool = false,
        seed: Bool = false,
        camera: Bool = false
    ) {
        self.character = character
        self.clothing = clothing
        self.location = location
        self.style = style
        self.brand = brand
        self.audio = audio
        self.seed = seed
        self.camera = camera
    }
}

public struct Scene: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var mode: SceneMode
    public var prompt: String
    public var negativePrompt: String?
    public var durationSeconds: Double
    public var aspectRatio: String?
    public var resolution: SceneResolution?
    public var attachedContinuityElements: [AttachedContinuityElement]
    public var consistencyLocks: ConsistencyLocks
    public var generations: [SceneGeneration]

    public init(
        id: String = UUID().uuidString,
        name: String,
        mode: SceneMode = .textToVideo,
        prompt: String = "",
        negativePrompt: String? = nil,
        durationSeconds: Double = 5.0,
        aspectRatio: String? = nil,
        resolution: SceneResolution? = nil,
        attachedContinuityElements: [AttachedContinuityElement] = [],
        consistencyLocks: ConsistencyLocks = ConsistencyLocks(),
        generations: [SceneGeneration] = []
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.durationSeconds = durationSeconds
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.attachedContinuityElements = attachedContinuityElements
        self.consistencyLocks = consistencyLocks
        self.generations = generations
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case mode
        case prompt
        case negativePrompt = "negative_prompt"
        case durationSeconds = "duration_seconds"
        case aspectRatio = "aspect_ratio"
        case resolution
        case attachedContinuityElements = "attached_continuity_elements"
        case consistencyLocks = "consistency_locks"
        case generations
    }
}

// MARK: - Mock Fixtures
extension Scene {
    public static var mock: Scene {
        Scene(
            name: "Introduction Scene",
            prompt: "A man walking through a futuristic city",
            durationSeconds: 5.0,
            attachedContinuityElements: [
                AttachedContinuityElement(elementId: "mock-char-1", type: .character),
                AttachedContinuityElement(elementId: "mock-loc-1", type: .location)
            ]
        )
    }
}
