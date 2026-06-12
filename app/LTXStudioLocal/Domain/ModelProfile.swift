import Foundation

public enum ModelFamily: String, Codable, CaseIterable {
    case ltxVideo = "LTX-Video"
    case stableVideoDiffusion = "Stable Video Diffusion"
    case upscaler = "Upscaler"
    case other = "Other"
}

public enum QualityLevel: String, Codable, CaseIterable {
    case fastDraft = "Fast Draft"
    case balanced = "Balanced"
    case production = "Production"
    case cinematic = "Cinematic"
}

public struct ModelProfile: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var purpose: String
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
        purpose: String,
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
        self.purpose = purpose
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
        case purpose
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
            purpose: "General purpose video generation",
            modelFamily: .ltxVideo,
            version: "1.0",
            memoryRequirement: 16,
            qualityLevel: .balanced,
            installed: true,
            recommended: true
        )
    }

    public static var mocks: [ModelProfile] {
        [
            ModelProfile(
                id: "ltx-2.3-distilled",
                name: "LTX-2.3 Distilled",
                purpose: "Fast, high-quality video generation (recommended for most users)",
                modelFamily: .ltxVideo,
                version: "2.3",
                memoryRequirement: 16,
                qualityLevel: .fastDraft,
                installed: true,
                recommended: true
            ),
            ModelProfile(
                id: "ltx-2.3-dev",
                name: "LTX-2.3 Dev",
                purpose: "Full precision model for maximum quality and creative control",
                modelFamily: .ltxVideo,
                version: "2.3",
                memoryRequirement: 32,
                qualityLevel: .production,
                installed: false,
                recommended: false
            ),
            ModelProfile(
                id: "ltx-2.3-quantized",
                name: "LTX-2.3 Quantized",
                purpose: "Memory-efficient version for 8GB or 16GB Macs",
                modelFamily: .ltxVideo,
                version: "2.3",
                memoryRequirement: 8,
                qualityLevel: .balanced,
                installed: false,
                recommended: false
            ),
            ModelProfile(
                id: "spatial-upscaler",
                name: "Spatial Upscaler",
                purpose: "Enhances resolution and fine details of generated clips",
                modelFamily: .upscaler,
                version: "1.0",
                memoryRequirement: 16,
                qualityLevel: .production,
                installed: true,
                recommended: true
            ),
            ModelProfile(
                id: "temporal-upscaler",
                name: "Temporal Upscaler",
                purpose: "Improves motion smoothness and frame consistency",
                modelFamily: .upscaler,
                version: "1.0",
                memoryRequirement: 16,
                qualityLevel: .production,
                installed: false,
                recommended: true
            )
        ]
    }
}
