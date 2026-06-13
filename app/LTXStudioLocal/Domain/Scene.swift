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
    public var characterIdentity: Bool = false
    public var location: Bool = false
    public var style: Bool = false
    public var brand: Bool = false
    public var audioIdentity: Bool = false
    public var seed: Bool = false
    // Keeping these as they were in the original but not explicitly requested
    public var clothing: Bool = false
    public var camera: Bool = false

    public init(
        characterIdentity: Bool = false,
        location: Bool = false,
        style: Bool = false,
        brand: Bool = false,
        audioIdentity: Bool = false,
        seed: Bool = false,
        clothing: Bool = false,
        camera: Bool = false
    ) {
        self.characterIdentity = characterIdentity
        self.location = location
        self.style = style
        self.brand = brand
        self.audioIdentity = audioIdentity
        self.seed = seed
        self.clothing = clothing
        self.camera = camera
    }

    enum CodingKeys: String, CodingKey {
        case characterIdentity = "character_identity"
        case location
        case style
        case brand
        case audioIdentity = "audio_identity"
        case seed
        case clothing
        case camera
    }
}

public enum AudioMode: String, Codable, CaseIterable {
    case generate = "generate"
    case mute = "mute"
    case imported = "imported"
    case voiceover = "voiceover"
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
    public var referenceImagePath: String?
    public var audioMode: AudioMode
    public var audioReferencePath: String?
    public var attachedContinuityElements: [AttachedContinuityElement]
    public var consistencyLocks: ConsistencyLocks
    public var generations: [SceneGeneration]

    // Advanced Settings
    public var seed: Int?
    public var inferenceSteps: Int?
    public var guidanceScale: Float?
    public var fps: Int?
    public var frameCount: Int?
    public var modelProfileId: String?
    public var loraWeights: [String: Float]?
    public var upscalerId: String?
    public var quantizationMode: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        mode: SceneMode = .textToVideo,
        prompt: String = "",
        negativePrompt: String? = nil,
        durationSeconds: Double = 5.0,
        aspectRatio: String? = nil,
        resolution: SceneResolution? = nil,
        referenceImagePath: String? = nil,
        audioMode: AudioMode = .generate,
        audioReferencePath: String? = nil,
        attachedContinuityElements: [AttachedContinuityElement] = [],
        consistencyLocks: ConsistencyLocks = ConsistencyLocks(),
        generations: [SceneGeneration] = [],
        seed: Int? = nil,
        inferenceSteps: Int? = nil,
        guidanceScale: Float? = nil,
        fps: Int? = nil,
        frameCount: Int? = nil,
        modelProfileId: String? = nil,
        loraWeights: [String: Float]? = nil,
        upscalerId: String? = nil,
        quantizationMode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.durationSeconds = durationSeconds
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.referenceImagePath = referenceImagePath
        self.audioMode = audioMode
        self.audioReferencePath = audioReferencePath
        self.attachedContinuityElements = attachedContinuityElements
        self.consistencyLocks = consistencyLocks
        self.generations = generations
        self.seed = seed
        self.inferenceSteps = inferenceSteps
        self.guidanceScale = guidanceScale
        self.fps = fps
        self.frameCount = frameCount
        self.modelProfileId = modelProfileId
        self.loraWeights = loraWeights
        self.upscalerId = upscalerId
        self.quantizationMode = quantizationMode
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
        case referenceImagePath = "reference_image_path"
        case audioMode = "audio_mode"
        case audioReferencePath = "audio_reference_path"
        case attachedContinuityElements = "attached_continuity_elements"
        case consistencyLocks = "consistency_locks"
        case generations
        case seed
        case inferenceSteps = "inference_steps"
        case guidanceScale = "guidance_scale"
        case fps
        case frameCount = "frame_count"
        case modelProfileId = "model_profile_id"
        case loraWeights = "lora_weights"
        case upscalerId = "upscaler_id"
        case quantizationMode = "quantization_mode"
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
