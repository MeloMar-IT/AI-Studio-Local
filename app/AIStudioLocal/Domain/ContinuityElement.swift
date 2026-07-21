import Foundation

public enum ContinuityElementType: String, Codable, CaseIterable {
    case character
    case location
    case style
    case camera
    case audio
    case voiceClone = "voice_clone"
    case brand
    case promptBlock = "prompt_block"
    case lora
    case exportTemplate = "export_template"

    public var iconName: String {
        switch self {
        case .character: return "person.fill"
        case .location: return "mappin.and.ellipse"
        case .style: return "paintpalette.fill"
        case .camera: return "video.fill"
        case .audio: return "waveform"
        case .voiceClone: return "mic.fill"
        case .brand: return "briefcase.fill"
        case .promptBlock: return "text.alignleft"
        case .lora: return "cpu"
        case .exportTemplate: return "square.and.arrow.up.fill"
        }
    }
}

public struct ContinuityAsset: Codable, Identifiable, Equatable {
    public let id: String
    public let path: String
    public let type: String

    public init(id: String = UUID().uuidString, path: String, type: String) {
        self.id = id
        self.path = path
        self.type = type
    }
}

public struct ContinuityElement: Codable, Identifiable, Equatable {
    public let id: String
    public let type: ContinuityElementType
    public var name: String
    public var description: String
    public var promptBlock: String
    public var negativePrompt: String?
    public var voiceCloneReferencePath: String?
    public var trainedLoraPath: String?
    // The exact token the LoRA was trained to associate with this character's appearance
    // (captions written during preprocessing are just this word by itself, nothing else --
    // see worker/outputs/temp_training/<id>/captions/*.txt). The trained weights only get
    // strongly invoked when this token is present in the generation prompt; without it, the
    // LoRA is merged into the model but has nothing in the text conditioning to activate it,
    // so generations look like the base model instead of the trained character.
    public var triggerWord: String?
    public var isTraining: Bool?
    public var tags: [String]
    public var assets: [ContinuityAsset]
    public let createdAt: Date
    public var modifiedAt: Date

    public var iconName: String {
        return type.iconName
    }

    public init(
        id: String = UUID().uuidString,
        type: ContinuityElementType,
        name: String,
        description: String = "",
        promptBlock: String,
        negativePrompt: String? = nil,
        voiceCloneReferencePath: String? = nil,
        trainedLoraPath: String? = nil,
        triggerWord: String? = nil,
        isTraining: Bool? = nil,
        tags: [String] = [],
        assets: [ContinuityAsset] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.promptBlock = promptBlock
        self.negativePrompt = negativePrompt
        self.voiceCloneReferencePath = voiceCloneReferencePath
        self.trainedLoraPath = trainedLoraPath
        self.triggerWord = triggerWord
        self.isTraining = isTraining
        self.tags = tags
        self.assets = assets
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case description
        case promptBlock = "prompt_block"
        case negativePrompt = "negative_prompt"
        case voiceCloneReferencePath = "voice_clone_reference_path"
        case trainedLoraPath = "trained_lora_path"
        case triggerWord = "trigger_word"
        case isTraining = "is_training"
        case tags
        case assets
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
    }
}
