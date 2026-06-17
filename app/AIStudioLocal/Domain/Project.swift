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
    public var modelProfileId: String?
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
        modelProfileId: String? = nil,
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
        self.modelProfileId = modelProfileId
        self.aspectRatio = aspectRatio
        self.scenes = scenes
        self.timeline = timeline
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Project.currentSchemaVersion
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        self.defaultBrandKitId = try container.decodeIfPresent(String.self, forKey: .defaultBrandKitId)
        self.modelProfileId = try container.decodeIfPresent(String.self, forKey: .modelProfileId)
        self.aspectRatio = try container.decode(String.self, forKey: .aspectRatio)
        self.scenes = try container.decode([String].self, forKey: .scenes)
        self.timeline = try container.decode(Timeline.self, forKey: .timeline)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(defaultBrandKitId, forKey: .defaultBrandKitId)
        try container.encode(modelProfileId, forKey: .modelProfileId)
        try container.encode(aspectRatio, forKey: .aspectRatio)
        try container.encode(scenes, forKey: .scenes)
        try container.encode(timeline, forKey: .timeline)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case schemaVersion = "schema_version"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case defaultBrandKitId = "default_brand_kit_id"
        case modelProfileId = "model_profile_id"
        case aspectRatio = "aspect_ratio"
        case scenes
        case timeline
    }
}

#if DEBUG
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
#endif
