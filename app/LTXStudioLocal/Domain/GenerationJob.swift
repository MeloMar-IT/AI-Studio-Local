import Foundation

public enum JobStatus: String, Codable, CaseIterable {
    case queued
    case preparingPrompt = "preparing_prompt"
    case checkingHardware = "checking_hardware"
    case loadingModel = "loading_model"
    case preparingInputs = "preparing_inputs"
    case generatingVideo = "generating_video"
    case generatingAudio = "generating_audio"
    case upscaling
    case encodingOutput = "encoding_output"
    case savingMetadata = "saving_metadata"
    case downloading
    case completed
    case failed
    case cancelled
}

public struct JobOutputPaths: Codable, Equatable {
    public var video: String?
    public var preview: String?
    public var metadata: String?

    public init(video: String? = nil, preview: String? = nil, metadata: String? = nil) {
        self.video = video
        self.preview = preview
        self.metadata = metadata
    }
}

public struct JobErrorInformation: Codable, Equatable {
    public var code: String
    public var message: String
    public var technicalDetail: String?
    public var suggestedAction: String?

    public init(code: String, message: String, technicalDetail: String? = nil, suggestedAction: String? = nil) {
        self.code = code
        self.message = message
        self.technicalDetail = technicalDetail
        self.suggestedAction = suggestedAction
    }

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case technicalDetail = "technical_detail"
        case suggestedAction = "suggested_action"
    }
}

public struct GenerationJob: Codable, Identifiable, Equatable {
    public let id: String
    public let projectId: String
    public let sceneId: String
    public var status: JobStatus
    public var mode: SceneMode
    public var modelProfile: ModelProfileSummary?
    public var progress: Double
    public var startedAt: Date?
    public var completedAt: Date?
    public var sceneName: String?
    public var message: String?
    public var outputPaths: JobOutputPaths?
    public var errorInformation: JobErrorInformation?

    public init(
        id: String = UUID().uuidString,
        projectId: String,
        sceneId: String,
        status: JobStatus = .queued,
        mode: SceneMode = .textToVideo,
        modelProfile: ModelProfileSummary? = nil,
        progress: Double = 0,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        sceneName: String? = nil,
        message: String? = nil,
        outputPaths: JobOutputPaths? = nil,
        errorInformation: JobErrorInformation? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.sceneId = sceneId
        self.status = status
        self.mode = mode
        self.modelProfile = modelProfile
        self.progress = progress
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.sceneName = sceneName
        self.message = message
        self.outputPaths = outputPaths
        self.errorInformation = errorInformation
    }

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case sceneId = "scene_id"
        case status
        case mode
        case modelProfile = "model_profile"
        case progress
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case sceneName = "scene_name"
        case message
        case outputPaths = "output_paths"
        case errorInformation = "error_information"
    }
}

public struct ModelProfileSummary: Codable, Equatable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Mock Fixtures
extension GenerationJob {
    public static var mock: GenerationJob {
        GenerationJob(
            projectId: "mock-project",
            sceneId: "mock-scene",
            status: .generatingVideo,
            modelProfile: ModelProfileSummary(id: "fast-draft", name: "Fast Draft"),
            progress: 0.45
        )
    }
}
