import XCTest
@testable import LTXStudioLocal

final class ProjectStoreTests: XCTestCase {
    var fileManager: FileManager!
    var projectStore: FileProjectStore!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        fileManager = FileManager.default
        projectStore = FileProjectStore(fileManager: fileManager)
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? fileManager.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testSaveAndLoadProject() throws {
        let project = Project.mock
        let scenes = [Scene.mock, Scene(name: "Another Scene", prompt: "A robot in a garden")]
        let projectURL = tempDirectory.appendingPathComponent("TestProject.ltxproject")

        // 1. Save
        try projectStore.save(project: project, scenes: scenes, to: projectURL)

        // 2. Verify files exist
        XCTAssertTrue(fileManager.fileExists(atPath: projectURL.appendingPathComponent("project.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: projectURL.appendingPathComponent("timeline.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: projectURL.appendingPathComponent("README.md").path))
        XCTAssertTrue(fileManager.fileExists(atPath: projectURL.appendingPathComponent(".gitignore").path))
        XCTAssertTrue(fileManager.fileExists(atPath: projectURL.appendingPathComponent(".gitattributes").path))
        XCTAssertTrue(fileManager.fileExists(atPath: projectURL.appendingPathComponent("scenes").path))
        XCTAssertTrue(fileManager.fileExists(atPath: projectURL.appendingPathComponent("assets/images").path))

        for scene in scenes {
            let sceneDir = projectURL.appendingPathComponent("scenes").appendingPathComponent(scene.id)
            XCTAssertTrue(fileManager.fileExists(atPath: sceneDir.appendingPathComponent("scene.json").path))
            XCTAssertTrue(fileManager.fileExists(atPath: sceneDir.appendingPathComponent("prompt.md").path))
            XCTAssertTrue(fileManager.fileExists(atPath: sceneDir.appendingPathComponent("generations").path))
            XCTAssertTrue(fileManager.fileExists(atPath: sceneDir.appendingPathComponent("references").path))

            // Verify prompt content
            let promptContent = try String(contentsOf: sceneDir.appendingPathComponent("prompt.md"), encoding: .utf8)
            XCTAssertEqual(promptContent, scene.prompt)
        }

        // 3. Load
        let (loadedProject, loadedScenes) = try projectStore.load(from: projectURL)

        // 4. Verify content
        XCTAssertEqual(loadedProject.id, project.id)
        XCTAssertEqual(loadedProject.name, project.name)
        XCTAssertEqual(loadedProject.timeline.clips.count, project.timeline.clips.count)
        XCTAssertEqual(loadedScenes.count, scenes.count)

        let loadedSceneIds = Set(loadedScenes.map { $0.id })
        let originalSceneIds = Set(scenes.map { $0.id })
        XCTAssertEqual(loadedSceneIds, originalSceneIds)
    }

    func testSaveAndLoadGenerationMetadata() throws {
        let projectURL = tempDirectory.appendingPathComponent("MetadataProject.ltxproject")
        let scene = Scene.mock
        let job = GenerationJob(
            id: "gen-123",
            projectId: "mock-project",
            sceneId: scene.id,
            status: .completed,
            progress: 1.0
        )
        let composedPrompt = "Composed: A man walking through a futuristic city with consistent character"

        // 1. Setup project structure
        try projectStore.save(project: Project.mock, scenes: [scene], to: projectURL)

        // 2. Save metadata
        try projectStore.saveGenerationMetadata(job, for: scene.id, composedPrompt: composedPrompt, to: projectURL)

        // 3. Verify files
        let genDir = projectURL
            .appendingPathComponent("scenes")
            .appendingPathComponent(scene.id)
            .appendingPathComponent("generations")
            .appendingPathComponent(job.id)

        XCTAssertTrue(fileManager.fileExists(atPath: genDir.appendingPathComponent("metadata.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: genDir.appendingPathComponent("composed-prompt.md").path))

        // 4. Load metadata
        let loadedJob = try projectStore.loadGenerationMetadata(for: scene.id, generationId: job.id, from: projectURL)

        // 5. Verify content
        XCTAssertEqual(loadedJob.id, job.id)
        XCTAssertEqual(loadedJob.status, .completed)
        XCTAssertEqual(loadedJob.progress, 1.0)

        let loadedComposedPrompt = try String(contentsOf: genDir.appendingPathComponent("composed-prompt.md"), encoding: .utf8)
        XCTAssertEqual(loadedComposedPrompt, composedPrompt)
    }

    func testLoadMissingProjectThrowsError() {
        let projectURL = tempDirectory.appendingPathComponent("NonExistent.ltxproject")
        XCTAssertThrowsError(try projectStore.load(from: projectURL)) { error in
            XCTEqualStoreError(error as? ProjectStoreError, .invalidProjectFolder)
        }
    }

    func testValidateProjectFolder() throws {
        let projectURL = tempDirectory.appendingPathComponent("Valid.ltxproject")
        try projectStore.save(project: Project.mock, scenes: [], to: projectURL)

        // Should not throw
        try projectStore.validateProjectFolder(at: projectURL)

        // Test missing .ltxproject extension
        let invalidExtensionURL = tempDirectory.appendingPathComponent("InvalidExtension")
        try fileManager.createDirectory(at: invalidExtensionURL, withIntermediateDirectories: true)
        XCTAssertThrowsError(try projectStore.validateProjectFolder(at: invalidExtensionURL)) { error in
            XCTEqualStoreError(error as? ProjectStoreError, .invalidProjectFolder)
        }

        // Test missing project.json
        let missingFileURL = tempDirectory.appendingPathComponent("MissingFile.ltxproject")
        try fileManager.createDirectory(at: missingFileURL, withIntermediateDirectories: true)
        XCTAssertThrowsError(try projectStore.validateProjectFolder(at: missingFileURL)) { error in
            XCTEqualStoreError(error as? ProjectStoreError, .missingProjectFile)
        }
    }

    func testDetectCorruptProject() throws {
        let projectURL = tempDirectory.appendingPathComponent("Corrupt.ltxproject")
        try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)

        XCTAssertTrue(projectStore.detectCorruptProject(at: projectURL))

        try projectStore.save(project: Project.mock, scenes: [], to: projectURL)
        XCTAssertFalse(projectStore.detectCorruptProject(at: projectURL))
    }

    func testSchemaVersionAndMigration() throws {
        let projectURL = tempDirectory.appendingPathComponent("OldProject.ltxproject")

        // Create an old project manually
        try projectStore.save(project: Project.mock, scenes: [], to: projectURL)

        let projectFileURL = projectURL.appendingPathComponent("project.json")
        var projectData = try Data(contentsOf: projectFileURL)

        // Manually lower the version in JSON using the same decoder configuration
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var project = try decoder.decode(Project.self, from: projectData)
        project.schemaVersion = 0

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        projectData = try encoder.encode(project)
        try projectData.write(to: projectFileURL)

        // Loading should trigger migration
        let (loadedProject, _) = try projectStore.load(from: projectURL)

        XCTAssertEqual(loadedProject.schemaVersion, Project.currentSchemaVersion)

        // Verify it was saved back to disk
        let updatedData = try Data(contentsOf: projectFileURL)
        let updatedProject = try decoder.decode(Project.self, from: updatedData)
        XCTAssertEqual(updatedProject.schemaVersion, Project.currentSchemaVersion)
    }

    func testIncompatibleVersion() throws {
        let projectURL = tempDirectory.appendingPathComponent("FutureProject.ltxproject")
        try projectStore.save(project: Project.mock, scenes: [], to: projectURL)

        let projectFileURL = projectURL.appendingPathComponent("project.json")
        var projectData = try Data(contentsOf: projectFileURL)

        // Manually increase the version in JSON
        var json = try JSONSerialization.jsonObject(with: projectData) as! [String: Any]
        json["schema_version"] = 999
        projectData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        try projectData.write(to: projectFileURL)

        XCTAssertThrowsError(try projectStore.load(from: projectURL)) { error in
            if case .incompatibleVersion(let version) = error as? ProjectStoreError {
                XCTAssertEqual(version, 999)
            } else {
                XCTFail("Expected incompatibleVersion error, got \(error)")
            }
        }
    }

    func testGitFriendlyFilesContent() throws {
        let project = Project.mock
        let projectURL = tempDirectory.appendingPathComponent("GitProject.ltxproject")
        try projectStore.save(project: project, scenes: [], to: projectURL)

        // Verify README
        let readmeContent = try String(contentsOf: projectURL.appendingPathComponent("README.md"), encoding: .utf8)
        XCTAssertTrue(readmeContent.contains(project.name))
        XCTAssertTrue(readmeContent.contains("Git Compatibility"))

        // Verify .gitignore
        let gitignoreContent = try String(contentsOf: projectURL.appendingPathComponent(".gitignore"), encoding: .utf8)
        XCTAssertTrue(gitignoreContent.contains("scenes/*/generations/*/output.mp4"))
        XCTAssertTrue(gitignoreContent.contains("exports/*.mp4"))

        // Verify .gitattributes
        let gitattributesContent = try String(contentsOf: projectURL.appendingPathComponent(".gitattributes"), encoding: .utf8)
        XCTAssertTrue(gitattributesContent.contains("*.mp4 filter=lfs"))
    }

    func testPrettyPrintedJSON() throws {
        let project = Project.mock
        let projectURL = tempDirectory.appendingPathComponent("PrettyJSON.ltxproject")
        try projectStore.save(project: project, scenes: [], to: projectURL)

        let projectJSONPath = projectURL.appendingPathComponent("project.json").path
        let jsonString = try String(contentsOfFile: projectJSONPath, encoding: .utf8)

        // Basic check for pretty printing: should contain newlines and indentation
        XCTAssertTrue(jsonString.contains("\n"))
        XCTAssertTrue(jsonString.contains("  ")) // Assuming 2-space indentation
        XCTAssertTrue(jsonString.contains("\"id\" : \"\(project.id)\""))
    }

    private func XCTEqualStoreError(_ lhs: ProjectStoreError?, _ rhs: ProjectStoreError?) {
        switch (lhs, rhs) {
        case (.missingProjectFile, .missingProjectFile): break
        case (.invalidProjectFolder, .invalidProjectFolder): break
        case (.missingTimelineFile, .missingTimelineFile): break
        case (.incompatibleVersion, .incompatibleVersion): break
        default: XCTFail("\(String(describing: lhs)) is not equal to \(String(describing: rhs))")
        }
    }
}

extension ProjectStoreError: Equatable {
    public static func == (lhs: ProjectStoreError, rhs: ProjectStoreError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidProjectFolder, .invalidProjectFolder): return true
        case (.missingProjectFile, .missingProjectFile): return true
        case (.missingTimelineFile, .missingTimelineFile): return true
        case (.incompatibleVersion(let v1), .incompatibleVersion(let v2)): return v1 == v2
        case (.decodingError, .decodingError): return true
        case (.encodingError, .encodingError): return true
        case (.fileSystemError, .fileSystemError): return true
        default: return false
        }
    }
}
