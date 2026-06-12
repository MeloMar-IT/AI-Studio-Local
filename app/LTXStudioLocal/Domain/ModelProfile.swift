import Foundation

public enum ModelFamily: String, Codable, CaseIterable {
    case ltxVideo = "LTX-Video"
    case stableVideoDiffusion = "Stable Video Diffusion"
    case other = "Other"
}

public enum QualityLevel: String, Codable, CaseIterable {
    case fastDraft = "Fast Draft"
    case balanced = "Balanced"
    case production = "Production"
}

public struct ModelProfile: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var modelFamily: ModelFamily
    public var version: String?
    public var localPath: String?
    public var memoryRequirement: Int? // Required unified memory in GB
    public var qualityLevel: QualityLevel
    public var installed: Bool
    public var recommended: Bool

    public init(
        id: String,
        name: String,
        modelFamily: ModelFamily = .ltxVideo,
        version: String? = nil,
        localPath: String? = nil,
        memoryRequirement: Int? = nil,
        qualityLevel: QualityLevel = .balanced,
        installed: Bool = false,
        recommended: Bool = false
    ) {
        self.id = id
        self.name = name
        self.modelFamily = modelFamily
        self.version = version
        self.localPath = localPath
        self.memoryRequirement = memoryRequirement
        self.qualityLevel = qualityLevel
        self.installed = installed
        self.recommended = recommended
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case modelFamily = "model_family"
        case version
        case localPath = "local_path"
        case memoryRequirement = "memory_requirement"
        case qualityLevel = "quality_level"
        case installed
        case recommended
    }
}

// MARK: - Mock Fixtures
extension ModelProfile {
    public static var mock: ModelProfile {
        ModelProfile(
            id: "ltx-video-v1-balanced",
            name: "LTX Video v1 Balanced",
            modelFamily: .ltxVideo,
            version: "1.0",
            memoryRequirement: 16,
            qualityLevel: .balanced,
            installed: true,
            recommended: true
        )
    }
}
