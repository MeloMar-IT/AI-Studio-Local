import Foundation

public protocol ExportService {
    func exportProject(_ project: Project, scenes: [Scene], preset: ExportPreset, projectURL: URL) async throws -> ExportMetadata
}

public enum ExportError: Error, LocalizedError {
    case emptyTimeline
    case projectFolderMissing
    case fileSystemError(Error)

    public var errorDescription: String? {
        switch self {
        case .emptyTimeline:
            return "Cannot export an empty timeline. Please add clips first."
        case .projectFolderMissing:
            return "Project folder not found."
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        }
    }
}

public final class MockExportService: ExportService {
    private let fileManager: FileManager
    private let jsonEncoder: JSONEncoder

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }

    public func exportProject(_ project: Project, scenes: [Scene], preset: ExportPreset, projectURL: URL) async throws -> ExportMetadata {
        // 1. Validate timeline
        guard !project.timeline.clips.isEmpty else {
            throw ExportError.emptyTimeline
        }

        // 2. Create exports/ folder
        let exportsURL = projectURL.appendingPathComponent("exports")
        if !fileManager.fileExists(atPath: exportsURL.path) {
            try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
        }

        // 3. Prepare metadata
        let clipMetadata = project.timeline.clips.compactMap { clip -> ExportClipMetadata? in
            guard let scene = scenes.first(where: { $0.id == clip.sceneId }) else { return nil }
            return ExportClipMetadata(
                sceneId: scene.id,
                sceneName: scene.name,
                generationId: scene.generations.first?.id, // Mock: use first generation
                duration: clip.duration
            )
        }

        let exportId = UUID().uuidString
        let fileName = "export-\(exportId.prefix(8)).\(preset.format == .mp4 ? "mp4" : "mov")"
        let outputPath = "exports/\(fileName)"

        let metadata = ExportMetadata(
            id: exportId,
            projectId: project.id,
            projectName: project.name,
            preset: preset,
            clips: clipMetadata,
            outputPath: outputPath
        )

        // 4. Save metadata JSON
        let metadataURL = exportsURL.appendingPathComponent("metadata-\(exportId.prefix(8)).json")
        let data = try jsonEncoder.encode(metadata)
        try data.write(to: metadataURL)

        // 5. Create a dummy video file if it doesn't exist (optional, but good for mock)
        let dummyVideoURL = projectURL.appendingPathComponent(outputPath)
        if !fileManager.fileExists(atPath: dummyVideoURL.path) {
            try "Mock Video Content".data(using: .utf8)?.write(to: dummyVideoURL)
        }

        // Simulate some delay for export
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)

        return metadata
    }
}
