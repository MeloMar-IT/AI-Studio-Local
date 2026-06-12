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

    func testLoadMissingProjectThrowsError() {
        let projectURL = tempDirectory.appendingPathComponent("NonExistent.ltxproject")
        XCTAssertThrowsError(try projectStore.load(from: projectURL)) { error in
            XCTEqualStoreError(error as? ProjectStoreError, .missingProjectFile)
        }
    }

    private func XCTEqualStoreError(_ lhs: ProjectStoreError?, _ rhs: ProjectStoreError?) {
        switch (lhs, rhs) {
        case (.missingProjectFile, .missingProjectFile): break
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
        case (.decodingError, .decodingError): return true
        case (.encodingError, .encodingError): return true
        case (.fileSystemError, .fileSystemError): return true
        default: return false
        }
    }
}
