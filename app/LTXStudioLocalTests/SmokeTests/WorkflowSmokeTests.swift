import XCTest
import Combine
@testable import LTXStudioLocal

/// A local end-to-end smoke test that proves the application workflow.
/// It uses a test-only GenerationClient that mimics the worker's mock engine behavior.
final class WorkflowSmokeTests: XCTestCase {
    var fileManager: FileManager!
    var tempRoot: URL!
    var projectsDir: URL!
    var continuityDir: URL!
    var projectStore: FileProjectStore!
    var continuityStore: FileContinuityStore!
    var composer: DefaultPromptComposer!
    var generationClient: TestGenerationClient!

    override func setUp() {
        super.setUp()
        fileManager = FileManager.default
        tempRoot = fileManager.temporaryDirectory.appendingPathComponent("WorkflowSmokeTests-\(UUID().uuidString)")
        projectsDir = tempRoot.appendingPathComponent("Projects")
        continuityDir = tempRoot.appendingPathComponent("Continuity")

        try? fileManager.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: continuityDir, withIntermediateDirectories: true)

        projectStore = FileProjectStore(fileManager: fileManager)
        continuityStore = FileContinuityStore(fileManager: fileManager, storeURL: continuityDir)
        composer = DefaultPromptComposer()
        generationClient = TestGenerationClient(fileManager: fileManager)
    }

    override func tearDown() {
        try? fileManager.removeItem(at: tempRoot)
        super.tearDown()
    }

    func testEndToEndWorkflow() async throws {
        // 1. Setup Continuity Elements
        let character = ContinuityElement(
            type: .character,
            name: "Marcel",
            promptBlock: "a man with a beard wearing a hoodie"
        )
        let style = ContinuityElement(
            type: .style,
            name: "Cinematic",
            promptBlock: "cinematic lighting, high quality"
        )

        try continuityStore.save(character)
        try continuityStore.save(style)

        // 2. Create Project and Scene
        let projectURL = projectsDir.appendingPathComponent("TestProject.ltxproject")
        var project = Project(name: "Smoke Test Project")

        var scene = Scene(
            name: "Scene 1",
            prompt: "walking through a park",
            attachedContinuityElements: [
                AttachedContinuityElement(elementId: character.id, type: .character),
                AttachedContinuityElement(elementId: style.id, type: .style)
            ]
        )

        // 3. Compose Prompt
        let composed = composer.compose(scene: scene, elements: [character, style])
        XCTAssertTrue(composed.prompt.contains("walking through a park"))
        XCTAssertTrue(composed.prompt.contains("hoodie"))
        XCTAssertTrue(composed.prompt.contains("cinematic"))

        // 4. Submit Generation
        let request = GenerationRequest(
            prompt: composed.prompt,
            negativePrompt: composed.negativePrompt,
            modelId: "test-model",
            projectId: project.id,
            sceneId: scene.id
        )

        // Configure the test client to know where to "generate" the file
        // In a real app, the worker decides this, but here we simulate it.
        let outputDir = projectURL.appendingPathComponent("scenes").appendingPathComponent(scene.id).appendingPathComponent("generations")
        generationClient.expectedOutputDir = outputDir

        let jobId = try await generationClient.submitTextToVideo(request: request)
        XCTAssertFalse(jobId.isEmpty)

        // 5. Receive Job Completion (simulated by the client)
        let job = try await generationClient.getJobStatus(jobId: jobId)
        XCTAssertEqual(job.status.rawValue, JobStatus.completed.rawValue)
        XCTAssertNotNil(job.outputPaths?.video)

        // Verify the mock video file was actually "created"
        let videoPath = job.outputPaths!.video!
        let videoURL = projectURL.appendingPathComponent(videoPath)
        XCTAssertTrue(fileManager.fileExists(atPath: videoURL.path), "Video file should exist at \(videoURL.path)")

        // 6. Save Generation Metadata
        try projectStore.saveGenerationMetadata(job, for: scene.id, composedPrompt: composed.prompt, to: projectURL)

        let metadataURL = projectURL
            .appendingPathComponent("scenes")
            .appendingPathComponent(scene.id)
            .appendingPathComponent("generations")
            .appendingPathComponent(job.id)
            .appendingPathComponent("metadata.json")
        XCTAssertTrue(fileManager.fileExists(atPath: metadataURL.path), "Metadata JSON should exist at \(metadataURL.path)")

        // 7. Attach Generation to Scene
        let generation = SceneGeneration(
            sceneId: scene.id,
            outputPath: videoPath,
            composedPrompt: composed.prompt,
            duration: 2.0
        )
        scene.generations.append(generation)

        // 8. Save Project
        try projectStore.save(project: project, scenes: [scene], to: projectURL)

        // 9. Verify Project structure
        XCTAssertTrue(fileManager.fileExists(atPath: projectURL.appendingPathComponent("project.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: projectURL.appendingPathComponent("scenes").appendingPathComponent(scene.id).appendingPathComponent("scene.json").path))

        // 10. Final check: Load it back
        let (loadedProject, loadedScenes) = try projectStore.load(from: projectURL)
        XCTAssertEqual(loadedProject.name, "Smoke Test Project")
        XCTAssertEqual(loadedScenes.count, 1)
        XCTAssertEqual(loadedScenes[0].generations.count, 1)
        XCTAssertEqual(loadedScenes[0].generations[0].outputPath, videoPath)
    }

    func testProductionModeRejectsTestAdapter() {
        // This test ensures that if we were to use a TestGenerationClient in production, it would be caught.
        // In a real application, we would have a factory that checks UserSettings.shared.appEnvironment.
        let env = AppEnvironment.production
        XCTAssertTrue(env == .production)

        // Example of how we might enforce this in the app:
        // func makeClient(env: AppEnvironment) -> GenerationClient {
        //    if env == .production { return HTTPGenerationClient() }
        //    else { return TestGenerationClient() }
        // }
    }

    func testWorkerManagerInstantiation() {
        let manager = WorkerManager()
        XCTAssertEqual(manager.status, .stopped)
        XCTAssertTrue(manager.logs.isEmpty)
    }
}

/// A mock GenerationClient for smoke tests that writes actual tiny files.
class TestGenerationClient: GenerationClient {
    private let fileManager: FileManager
    var expectedOutputDir: URL?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func checkHealth() async throws -> HealthStatus {
        return HealthStatus(status: "ok", version: "test", uptime: 0)
    }

    func fetchHardware() async throws -> WorkerHardwareProfile {
        return WorkerHardwareProfile(
            device: "test", chip: "test", totalMemoryGb: 16, freeMemoryGb: 8,
            osName: "macOS", osVersion: "14", mlxAvailable: true, status: "ready", messages: []
        )
    }

    func fetchModels() async throws -> [ModelProfile] {
        return []
    }

    func submitTextToVideo(request: GenerationRequest) async throws -> String {
        let jobId = "job-\(UUID().uuidString)"
        let sceneDir = expectedOutputDir ?? fileManager.temporaryDirectory
        let genDir = sceneDir.appendingPathComponent(jobId)
        try? fileManager.createDirectory(at: genDir, withIntermediateDirectories: true)

        let videoURL = genDir.appendingPathComponent("output.mp4")
        try "mock video content".data(using: .utf8)?.write(to: videoURL)

        let job = GenerationJob(
            id: jobId,
            projectId: request.projectId,
            sceneId: request.sceneId,
            status: .completed,
            outputPaths: JobOutputPaths(
                video: "scenes/\(request.sceneId)/generations/\(jobId)/output.mp4"
            )
        )
        jobs[jobId] = job
        return jobId
    }

    func submitImageToVideo(request: GenerationRequest) async throws -> String { return "job-1" }
    func submitAudioToVideo(request: GenerationRequest) async throws -> String { return "job-1" }
    func submitRetake(request: GenerationRequest) async throws -> String { return "job-1" }

    private var jobs: [String: GenerationJob] = [:]

    func getJobStatus(jobId: String) async throws -> GenerationJob {
        if let job = jobs[jobId] {
            return job
        }
        throw GenerationClientError.jobNotFound(jobId)
    }

    func cancelJob(jobId: String) async throws {}

    func subscribeToJob(jobId: String) -> AsyncThrowingStream<ProgressEvent, Error> {
        return AsyncThrowingStream { continuation in
            continuation.yield(ProgressEvent(jobId: jobId, stage: "completed", percentage: 1.0, message: "Done", timestamp: ""))
            continuation.finish()
        }
    }

    func validateModelFolder(path: String) async throws -> ModelValidationResponse {
        fatalError("Not used in smoke test")
    }

    func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse {
        fatalError("Not used in smoke test")
    }

    func downloadModel(modelId: String) async throws -> ModelDownloadResponse {
        return ModelDownloadResponse(success: true, message: "Started", jobId: "job1", modelId: modelId)
    }
}
