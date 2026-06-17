import Foundation

public enum ModelQualityProfile: String, Codable, CaseIterable {
    case fastDraft = "Fast Draft"
    case balanced = "Balanced"
    case production = "Production"
}

public enum ModelFamily: String, Codable, CaseIterable {
    case ltxVideo = "LTX-Video"
    case stableVideoDiffusion = "Stable Video Diffusion"
    case upscaler = "Upscaler"
    case lora = "LoRA"
    case other = "Other"
}

public enum QualityLevel: String, Codable, CaseIterable {
    case fastDraft = "Fast Draft"
    case balanced = "Balanced"
    case production = "Production"
    case cinematic = "Cinematic"
}

public struct ModelProfile: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var description: String
    public var family: ModelFamily
    public var version: String?
    public var expectedFiles: [String]
    public var downloadUrls: [String: String]?
    public var memoryRequirementGB: Int?
    public var supportedModes: [String]
    public var recommendedHardware: String?
    public var localPath: String?
    public var installed: Bool
    public var recommended: Bool
    public var missingFiles: [String]
    public var status: String

    public var modelFamily: ModelFamily { family }
    public var purpose: String { description }
    public var memoryRequirement: Int? { memoryRequirementGB }
    public var canDownload: Bool { downloadUrls != nil && !downloadUrls!.isEmpty }
    public var qualityLevel: ModelQualityProfile {
        if id.contains("distilled") || id.contains("fast") {
            return .fastDraft
        } else if id.contains("production") || id.contains("high") {
            return .production
        }
        return .balanced
    }

    public init(
        id: String,
        name: String,
        description: String,
        family: ModelFamily = .ltxVideo,
        version: String? = nil,
        expectedFiles: [String] = [],
        downloadUrls: [String: String]? = nil,
        memoryRequirementGB: Int? = nil,
        supportedModes: [String] = [],
        recommendedHardware: String? = nil,
        localPath: String? = nil,
        installed: Bool = false,
        recommended: Bool = false,
        missingFiles: [String] = [],
        status: String = "missing"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.family = family
        self.version = version
        self.expectedFiles = expectedFiles
        self.downloadUrls = downloadUrls
        self.memoryRequirementGB = memoryRequirementGB
        self.supportedModes = supportedModes
        self.recommendedHardware = recommendedHardware
        self.localPath = localPath
        self.installed = installed
        self.recommended = recommended
        self.missingFiles = missingFiles
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case family
        case version
        case expectedFiles = "expected_files"
        case downloadUrls = "download_urls"
        case memoryRequirementGB = "memory_requirement_gb"
        case supportedModes = "supported_modes"
        case recommendedHardware = "recommended_hardware"
        case localPath = "local_path"
        case installed
        case recommended
        case missingFiles = "missing_files"
        case status
    }
}

// MARK: - Mock Fixtures
extension ModelProfile {
    public static var mock: ModelProfile {
        ModelProfile(
            id: "ltx-2.3-distilled",
            name: "LTX-2.3 Distilled",
            description: "Fast draft generation",
            family: .ltxVideo,
            version: "2.3",
            expectedFiles: ["ltx_video_2.3_distilled.safetensors", "config.json"],
            memoryRequirementGB: 16,
            supportedModes: ["text-to-video", "image-to-video"],
            recommendedHardware: "Apple M1 Pro 16GB or better",
            installed: true,
            recommended: true,
            status: "installed"
        )
    }

    public static var mocks: [ModelProfile] {
        [
            ModelProfile(
                id: "ltx-2.3-distilled",
                name: "LTX-2.3 Distilled",
                description: "Fast draft generation",
                family: .ltxVideo,
                version: "2.3",
                expectedFiles: ["ltx_video_2.3_distilled.safetensors", "config.json"],
                memoryRequirementGB: 16,
                supportedModes: ["text-to-video", "image-to-video"],
                recommendedHardware: "Apple M1 Pro 16GB or better",
                installed: true,
                recommended: true,
                status: "installed"
            ),
            ModelProfile(
                id: "ltx-2.3-dev",
                name: "LTX-2.3 Dev",
                description: "Production quality",
                family: .ltxVideo,
                version: "2.3",
                expectedFiles: ["ltx_video_2.3_dev.safetensors", "config.json"],
                memoryRequirementGB: 32,
                supportedModes: ["text-to-video", "image-to-video"],
                recommendedHardware: "Apple M2 Max 32GB or better",
                installed: false,
                recommended: false,
                status: "missing"
            ),
            ModelProfile(
                id: "spatial-upscaler",
                name: "Spatial Upscaler",
                description: "Enhances resolution",
                family: .upscaler,
                version: "1.0",
                expectedFiles: ["spatial_upscaler.safetensors"],
                memoryRequirementGB: 16,
                supportedModes: ["upscale"],
                recommendedHardware: "Apple M1 Pro 16GB or better",
                installed: true,
                recommended: true,
                status: "installed"
            )
        ]
    }
}
