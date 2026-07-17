import Foundation

public struct SceneGeneration: Codable, Identifiable, Equatable {
    public let id: String
    public let sceneId: String
    public var outputPath: String?
    public var previewImagePath: String?
    public var composedPrompt: String
    public var negativePrompt: String?
    public var modelProfile: ModelProfileSummary?
    public var seed: Int?
    public var resolution: SceneResolution?
    public var duration: Double
    public var createdAt: Date
    public var metadataPath: String?

    public init(
        id: String = UUID().uuidString,
        sceneId: String,
        outputPath: String? = nil,
        previewImagePath: String? = nil,
        composedPrompt: String,
        negativePrompt: String? = nil,
        modelProfile: ModelProfileSummary? = nil,
        seed: Int? = nil,
        resolution: SceneResolution? = nil,
        duration: Double,
        createdAt: Date = Date(),
        metadataPath: String? = nil
    ) {
        self.id = id
        self.sceneId = sceneId
        self.outputPath = outputPath
        self.previewImagePath = previewImagePath
        self.composedPrompt = composedPrompt
        self.negativePrompt = negativePrompt
        self.modelProfile = modelProfile
        self.seed = seed
        self.resolution = resolution
        self.duration = duration
        self.createdAt = createdAt
        self.metadataPath = metadataPath
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sceneId = "scene_id"
        case outputPath = "output_path"
        case previewImagePath = "preview_image_path"
        case composedPrompt = "composed_prompt"
        case negativePrompt = "negative_prompt"
        case modelProfile = "model_profile"
        case seed
        case resolution
        case duration
        case createdAt = "created_at"
        case metadataPath = "metadata_path"
    }
}
