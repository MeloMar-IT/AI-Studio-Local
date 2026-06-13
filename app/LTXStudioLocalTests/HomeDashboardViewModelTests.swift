import XCTest
import Combine
@testable import LTXStudioLocal

class HomeDashboardViewModelTests: XCTestCase {
    var viewModel: HomeDashboardViewModel!
    var mockProjectStore: MockProjectStore!
    var mockSettings: UserSettings!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        mockProjectStore = MockProjectStore()
        mockSettings = UserSettings.shared // We'll need to be careful here if UserSettings is a singleton
        mockSettings.projectsDirectory = tempDir.path

        viewModel = HomeDashboardViewModel(projectStore: mockProjectStore, settings: mockSettings)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testLoadRecentProjectsEmpty() {
        let expectation = XCTestExpectation(description: "Load recent projects")

        viewModel.$recentProjects
            .dropFirst() // Initial value
            .sink { projects in
                XCTAssertTrue(projects.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.loadRecentProjects()
        wait(for: [expectation], timeout: 2.0)
    }
}

class MockProjectStore: ProjectStore {
    var projectsToReturn: [Project] = []

    func save(project: Project, scenes: [Scene], to url: URL) throws {}
    func load(from url: URL) throws -> (Project, [Scene]) {
        if let project = projectsToReturn.first(where: { url.path.contains($0.name) }) {
            return (project, [])
        }
        throw ProjectStoreError.invalidProjectFolder
    }
    func saveGenerationMetadata(_ job: GenerationJob, for sceneId: String, composedPrompt: String?, to projectURL: URL) throws {}
    func loadGenerationMetadata(for sceneId: String, generationId: String, from projectURL: URL) throws -> GenerationJob {
        fatalError("Not implemented")
    }
    func saveExportMetadata(_ metadata: ExportMetadata, to projectURL: URL) throws {}
    func validateProjectFolder(at url: URL) throws {}
    func detectCorruptProject(at url: URL) -> Bool { return false }
    func migrateProject(at url: URL) throws {}
}

private var cancellables = Set<AnyCancellable>()
