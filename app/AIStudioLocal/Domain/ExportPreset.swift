import Foundation

public enum ExportFormat: String, Codable, CaseIterable {
    case mp4 = "MP4"
    case prores = "ProRes"
}

public struct ExportPreset: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var description: String
    public var width: Int
    public var height: Int
    public var aspectRatio: String
    public var format: ExportFormat

    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        width: Int,
        height: Int,
        aspectRatio: String,
        format: ExportFormat = .mp4
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.width = width
        self.height = height
        self.aspectRatio = aspectRatio
        self.format = format
    }
}

extension ExportPreset {
    public static let linkedin = ExportPreset(
        name: "LinkedIn 4:5",
        description: "Optimized for LinkedIn feed (1080x1350)",
        width: 1080,
        height: 1350,
        aspectRatio: "4:5"
    )

    public static let youtube = ExportPreset(
        name: "YouTube 16:9",
        description: "Standard Widescreen (1920x1080)",
        width: 1920,
        height: 1080,
        aspectRatio: "16:9"
    )

    public static let shorts = ExportPreset(
        name: "Shorts/Reels 9:16",
        description: "Vertical video for mobile (1080x1920)",
        width: 1080,
        height: 1920,
        aspectRatio: "9:16"
    )

    public static let proresMaster = ExportPreset(
        name: "ProRes Master",
        description: "High-quality master placeholder",
        width: 3840,
        height: 2160,
        aspectRatio: "16:9",
        format: .prores
    )

    public static let allPresets: [ExportPreset] = [.linkedin, .youtube, .shorts, .proresMaster]
}

public struct ExportMetadata: Codable, Identifiable {
    public let id: String
    public let projectId: String
    public let projectName: String
    public let timestamp: Date
    public let preset: ExportPreset
    public let clips: [ExportClipMetadata]
    public let brandKit: BrandKit?
    public let outputPath: String

    public init(
        id: String = UUID().uuidString,
        projectId: String,
        projectName: String,
        timestamp: Date = Date(),
        preset: ExportPreset,
        clips: [ExportClipMetadata],
        brandKit: BrandKit? = nil,
        outputPath: String
    ) {
        self.id = id
        self.projectId = projectId
        self.projectName = projectName
        self.timestamp = timestamp
        self.preset = preset
        self.clips = clips
        self.brandKit = brandKit
        self.outputPath = outputPath
    }
}

public struct ExportClipMetadata: Codable {
    public let sceneId: String
    public let sceneName: String
    public let generationId: String?
    public let duration: Double

    public init(sceneId: String, sceneName: String, generationId: String?, duration: Double) {
        self.sceneId = sceneId
        self.sceneName = sceneName
        self.generationId = generationId
        self.duration = duration
    }
}
