import Foundation

public struct TimelineClip: Codable, Equatable {
    public var sceneId: String
    public var startTime: Double
    public var duration: Double

    public init(sceneId: String, startTime: Double = 0, duration: Double = 0) {
        self.sceneId = sceneId
        self.startTime = startTime
        self.duration = duration
    }

    enum CodingKeys: String, CodingKey {
        case sceneId = "scene_id"
        case startTime = "start_time"
        case duration
    }
}

public struct Timeline: Codable, Equatable {
    public var clips: [TimelineClip]

    public init(clips: [TimelineClip] = []) {
        self.clips = clips
    }
}

public struct Project: Codable, Identifiable, Equatable {
    public static let currentSchemaVersion = 1

    public let id: String
    public var name: String
    public var schemaVersion: Int
    public var createdAt: Date
    public var modifiedAt: Date
    public var defaultBrandKitId: String?
    public var aspectRatio: String
    public var scenes: [String] // Path to scene.json or scene ID
    public var timeline: Timeline

    public init(
        id: String = UUID().uuidString,
        name: String,
        schemaVersion: Int = Project.currentSchemaVersion,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        defaultBrandKitId: String? = nil,
        aspectRatio: String = "16:9",
        scenes: [String] = [],
        timeline: Timeline = Timeline()
    ) {
        self.id = id
        self.name = name
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.defaultBrandKitId = defaultBrandKitId
        self.aspectRatio = aspectRatio
        self.scenes = scenes
        self.timeline = timeline
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case schemaVersion = "schema_version"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case defaultBrandKitId = "default_brand_kit_id"
        case aspectRatio = "aspect_ratio"
        case scenes
        case timeline
    }
}

// MARK: - Mock Fixtures
extension Project {
    public static var mock: Project {
        Project(
            name: "Cyberpunk Short Film",
            aspectRatio: "21:9",
            scenes: ["scene-001", "scene-002"],
            timeline: Timeline(clips: [
                TimelineClip(sceneId: "scene-001", startTime: 0, duration: 5.0),
                TimelineClip(sceneId: "scene-002", startTime: 5.0, duration: 3.5)
            ])
        )
    }
}
