import Foundation

public protocol ProjectStore {
    func save(project: Project, scenes: [Scene], to url: URL) throws
    func load(from url: URL) throws -> (Project, [Scene])
    func saveGenerationMetadata(_ job: GenerationJob, for sceneId: String, composedPrompt: String?, to projectURL: URL) throws
    func loadGenerationMetadata(for sceneId: String, generationId: String, from projectURL: URL) throws -> GenerationJob
    func saveExportMetadata(_ metadata: ExportMetadata, to projectURL: URL) throws
}

extension ProjectStoreError {
    public var asAppError: AppError {
        switch self {
        case .invalidProjectFolder:
            return AppError.projectLoadFailed(error: self)
        case .missingProjectFile, .missingTimelineFile:
            return AppError.projectLoadFailed(error: self)
        case .decodingError(let error):
            return AppError.projectLoadFailed(error: error)
        case .encodingError(let error):
            return AppError.projectSaveFailed(error: error)
        case .fileSystemError(let error):
            return AppError.projectSaveFailed(error: error)
        }
    }
}

public enum ProjectStoreError: Error {
    case invalidProjectFolder
    case missingProjectFile
    case missingTimelineFile
    case decodingError(Error)
    case encodingError(Error)
    case fileSystemError(Error)
}

public final class FileProjectStore: ProjectStore {
    private let fileManager: FileManager
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let settings: UserSettings

    public init(fileManager: FileManager = .default, settings: UserSettings = .shared) {
        self.fileManager = fileManager
        self.settings = settings
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }

    public func save(project: Project, scenes: [Scene], to url: URL) throws {
        do {
            // 1. Create directory structure
            try createDirectoryStructure(at: url)

            // 2. Save project.json
            let projectData = try jsonEncoder.encode(project)
            try projectData.write(to: url.appendingPathComponent("project.json"))

            // 3. Save timeline.json
            let timelineData = try jsonEncoder.encode(project.timeline)
            try timelineData.write(to: url.appendingPathComponent("timeline.json"))

            // 4. Save scenes
            let scenesDirectory = url.appendingPathComponent("scenes")
            for scene in scenes {
                try saveScene(scene, in: scenesDirectory)
            }

            // 5. Generate README.md
            try generateReadme(for: project, at: url)

        } catch let error as ProjectStoreError {
            throw error
        } catch {
            throw ProjectStoreError.fileSystemError(error)
        }
    }

    public func load(from url: URL) throws -> (Project, [Scene]) {
        let projectFileURL = url.appendingPathComponent("project.json")
        let timelineFileURL = url.appendingPathComponent("timeline.json")

        guard fileManager.fileExists(atPath: projectFileURL.path) else {
            throw ProjectStoreError.missingProjectFile
        }

        do {
            let projectData = try Data(contentsOf: projectFileURL)
            var project = try jsonDecoder.decode(Project.self, from: projectData)

            if fileManager.fileExists(atPath: timelineFileURL.path) {
                let timelineData = try Data(contentsOf: timelineFileURL)
                let timeline = try jsonDecoder.decode(Timeline.self, from: timelineData)
                project.timeline = timeline
            }

            var scenes: [Scene] = []
            let scenesDirectory = url.appendingPathComponent("scenes")
            if fileManager.fileExists(atPath: scenesDirectory.path) {
                let sceneFolders = try fileManager.contentsOfDirectory(at: scenesDirectory, includingPropertiesForKeys: nil)
                for folderURL in sceneFolders {
                    if let scene = try? loadScene(from: folderURL) {
                        scenes.append(scene)
                    }
                }
            }

            return (project, scenes)

        } catch let error as DecodingError {
            throw ProjectStoreError.decodingError(error)
        } catch {
            throw ProjectStoreError.fileSystemError(error)
        }
    }

    public func saveGenerationMetadata(_ job: GenerationJob, for sceneId: String, composedPrompt: String?, to projectURL: URL) throws {
        let generationDirectory = projectURL
            .appendingPathComponent("scenes")
            .appendingPathComponent(sceneId)
            .appendingPathComponent("generations")
            .appendingPathComponent(job.id)

        do {
            try fileManager.createDirectory(at: generationDirectory, withIntermediateDirectories: true)

            // Save metadata.json
            let metadataData = try jsonEncoder.encode(job)
            try metadataData.write(to: generationDirectory.appendingPathComponent("metadata.json"))

            // Save composed-prompt.md if provided
            if let composedPrompt = composedPrompt {
                try composedPrompt.write(to: generationDirectory.appendingPathComponent("composed-prompt.md"), atomically: true, encoding: .utf8)
            }
        } catch {
            throw ProjectStoreError.fileSystemError(error)
        }
    }

    public func loadGenerationMetadata(for sceneId: String, generationId: String, from projectURL: URL) throws -> GenerationJob {
        let metadataURL = projectURL
            .appendingPathComponent("scenes")
            .appendingPathComponent(sceneId)
            .appendingPathComponent("generations")
            .appendingPathComponent(generationId)
            .appendingPathComponent("metadata.json")

        guard fileManager.fileExists(atPath: metadataURL.path) else {
            throw ProjectStoreError.fileSystemError(NSError(domain: "ProjectStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Metadata not found"]))
        }

        do {
            let data = try Data(contentsOf: metadataURL)
            return try jsonDecoder.decode(GenerationJob.self, from: data)
        } catch {
            throw ProjectStoreError.decodingError(error)
        }
    }

    public func saveExportMetadata(_ metadata: ExportMetadata, to projectURL: URL) throws {
        let exportsDirectory = projectURL.appendingPathComponent("exports")

        do {
            try fileManager.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)

            let metadataURL = exportsDirectory.appendingPathComponent("metadata-\(metadata.id.prefix(8)).json")
            let data = try jsonEncoder.encode(metadata)
            try data.write(to: metadataURL)
        } catch {
            throw ProjectStoreError.fileSystemError(error)
        }
    }

    // MARK: - Private Helpers

    private func createDirectoryStructure(at url: URL) throws {
        let directories = [
            url,
            url.appendingPathComponent("scenes"),
            url.appendingPathComponent("assets"),
            url.appendingPathComponent("assets/images"),
            url.appendingPathComponent("assets/audio"),
            url.appendingPathComponent("assets/video"),
            url.appendingPathComponent("exports")
        ]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }

    private func saveScene(_ scene: Scene, in directory: URL) throws {
        let sceneDirectory = directory.appendingPathComponent(scene.id)
        try fileManager.createDirectory(at: sceneDirectory, withIntermediateDirectories: true)

        // Save scene.json
        let sceneData = try jsonEncoder.encode(scene)
        try sceneData.write(to: sceneDirectory.appendingPathComponent("scene.json"))

        // Save prompt.md
        try scene.prompt.write(to: sceneDirectory.appendingPathComponent("prompt.md"), atomically: true, encoding: .utf8)

        // Create generations and references folders
        try fileManager.createDirectory(at: sceneDirectory.appendingPathComponent("generations"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sceneDirectory.appendingPathComponent("references"), withIntermediateDirectories: true)
    }

    private func loadScene(from directory: URL) throws -> Scene {
        let sceneFileURL = directory.appendingPathComponent("scene.json")
        let sceneData = try Data(contentsOf: sceneFileURL)
        return try jsonDecoder.decode(Scene.self, from: sceneData)
    }

    private func generateReadme(for project: Project, at url: URL) throws {
        let readmeContent = """
        # \(project.name)

        This is an LTX Studio Local project.

        ## Project Details
        - **ID:** \(project.id)
        - **Created:** \(project.createdAt)
        - **Modified:** \(project.modifiedAt)
        - **Aspect Ratio:** \(project.aspectRatio)

        ## Folder Structure
        - `project.json`: Main project metadata.
        - `timeline.json`: Timeline and clip ordering.
        - `scenes/`: Individual scenes and their generations.
        - `assets/`: Project-specific assets (images, audio, video).
        - `exports/`: Rendered video files.
        """

        try readmeContent.write(to: url.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    }
}
