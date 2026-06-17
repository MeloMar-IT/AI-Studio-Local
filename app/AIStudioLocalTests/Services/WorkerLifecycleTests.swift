import XCTest
import Combine
@testable import AIStudioLocal

final class WorkerLifecycleTests: XCTestCase {
    var appState: AppState!
    var mockWorkerManager: MockWorkerManager!
    var mockHardwareProfiler: MockHardwareProfiler!
    var mockGenerationClient: MockGenerationClient!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockWorkerManager = MockWorkerManager()
        mockHardwareProfiler = MockHardwareProfiler()
        mockGenerationClient = MockGenerationClient()
        cancellables = []

        appState = AppState(
            hardwareProfiler: mockHardwareProfiler,
            generationClient: mockGenerationClient,
            workerManager: mockWorkerManager,
            environment: .development
        )
    }

    override func tearDown() {
        appState = nil
        mockWorkerManager = nil
        mockHardwareProfiler = nil
        mockGenerationClient = nil
        cancellables = nil
        super.tearDown()
    }

    func testWorkerOfflineState() {
        XCTAssertFalse(appState.isWorkerAvailable)
        XCTAssertEqual(appState.workerStatus, .stopped)
    }

    func testWorkerOnlineStateTransitions() async {
        // Initially, the init Task might start the worker.
        // For this test, we want to control it manually.

        // 1. Reset state
        mockWorkerManager.startWorkerCallCount = 0
        mockWorkerManager.status = .stopped
        mockGenerationClient.healthStatus = nil

        // 2. Start worker manually
        await appState.startWorker()
        XCTAssertEqual(mockWorkerManager.startWorkerCallCount, 1)

        // 3. Simulate process starting
        mockWorkerManager.status = .starting

        // Wait for AppState to observe status change
        let startingExpectation = XCTestExpectation(description: "AppState observes starting status")
        appState.$workerStatus
            .sink { status in
                if status == .starting {
                    startingExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        await fulfillment(of: [startingExpectation], timeout: 2.0)
        XCTAssertEqual(appState.workerStatus, .starting)

        // 4. Simulate health check passing
        mockGenerationClient.healthStatus = HealthStatus(status: "ok", version: "1.0.0", uptime: 10.0)

        let runningExpectation = XCTestExpectation(description: "AppState observes running status")
        appState.$workerStatus
            .sink { status in
                if status == .running {
                    runningExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        await appState.checkWorkerHealth()

        await fulfillment(of: [runningExpectation], timeout: 2.0)
        XCTAssertTrue(appState.isWorkerAvailable)
        XCTAssertEqual(appState.workerVersion, "1.0.0")
        XCTAssertEqual(appState.workerStatus, .running)
    }

    func testRetryConnection() async {
        mockGenerationClient.healthStatus = HealthStatus(status: "ok", version: "1.0.0", uptime: 10.0)

        await appState.checkWorkerHealth()

        XCTAssertTrue(appState.isWorkerAvailable)
        XCTAssertEqual(appState.workerVersion, "1.0.0")
    }

    func testAutoStartWorkerOnAppLaunch() async {
        // 1. Setup AppState where worker is initially unavailable
        mockGenerationClient.healthStatus = nil // Worker is offline
        mockWorkerManager.startWorkerCallCount = 0

        let expectation = XCTestExpectation(description: "Worker starts automatically")

        // Observe startWorkerCallCount or status
        // Since we can't easily observe startWorkerCallCount, we'll poll it or use status

        // Re-init with mocks
        let localAppState = AppState(
            hardwareProfiler: mockHardwareProfiler,
            generationClient: mockGenerationClient,
            workerManager: mockWorkerManager,
            environment: .development
        )

        // Check periodically if startWorker was called
        for _ in 0..<50 { // 5 seconds total
            if mockWorkerManager.startWorkerCallCount > 0 {
                expectation.fulfill()
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertGreaterThanOrEqual(mockWorkerManager.startWorkerCallCount, 1)

        // Verify that activeError is NOT set while it's starting (due to our change)
        XCTAssertNil(localAppState.activeError)
    }

    func testNoErrorWhenWorkerStarting() async {
        // 1. Setup worker in starting state
        mockWorkerManager.status = .starting
        mockGenerationClient.healthStatus = nil // Health check will fail

        // 2. Perform health check
        await appState.checkWorkerHealth()

        // 3. Verify error is not set
        XCTAssertNil(appState.activeError)
        XCTAssertFalse(appState.isWorkerAvailable)
    }

    func testErrorWhenRunningWorkerGoesOffline() async {
        // 1. Setup worker in running state
        mockWorkerManager.status = .running
        mockGenerationClient.healthStatus = nil // Health check will fail

        // 2. Perform health check
        await appState.checkWorkerHealth()

        // 3. Verify error IS set
        XCTAssertNotNil(appState.activeError)
        XCTAssertEqual(appState.activeError?.title, "Worker Unavailable")
        XCTAssertFalse(appState.isWorkerAvailable)
        // workerStatus should remain running if it was running, but checkWorkerHealth sets it to stopped if it goes offline
        XCTAssertEqual(appState.workerStatus, .stopped)
    }

    func testNoErrorWhenStoppedWorkerHealthCheckFails() async {
        // 1. Setup worker in stopped state
        mockWorkerManager.status = .stopped
        mockGenerationClient.healthStatus = nil // Health check will fail

        // 2. Perform health check
        await appState.checkWorkerHealth()

        // 3. Verify error is not set (it should trigger startWorker instead)
        XCTAssertNil(appState.activeError)
    }

    func testHealthCheckTriggersStartWorkerIfStopped() async {
        // 1. Setup worker in stopped state
        mockWorkerManager.status = .stopped
        mockWorkerManager.startWorkerCallCount = 0
        mockGenerationClient.healthStatus = nil // Health check will fail

        // 2. Perform health check
        await appState.checkWorkerHealth()

        // 3. Verify startWorker was triggered
        // It's triggered in a Task, so we might need to wait a tiny bit
        for _ in 0..<20 {
            if mockWorkerManager.startWorkerCallCount > 0 {
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        XCTAssertGreaterThanOrEqual(mockWorkerManager.startWorkerCallCount, 1)
    }
}

class MockWorkerManager: WorkerManagerProtocol {
    @Published var status: WorkerStatus = .stopped
    var statusPublisher: Published<WorkerStatus>.Publisher { $status }

    @Published var logs: String = ""
    var logsPublisher: Published<String>.Publisher { $logs }

    var startWorkerCallCount = 0
    var stopWorkerCallCount = 0

    func startWorker() async throws {
        startWorkerCallCount += 1
    }

    func stopWorker() {
        stopWorkerCallCount += 1
        status = .stopped
    }

    func clearLogs() {
        logs = ""
    }
}

class MockGenerationClient: GenerationClient {
    var healthStatus: HealthStatus?
    var hardwareProfile: WorkerHardwareProfile?
    var models: [ModelProfile] = []

    func checkHealth() async throws -> HealthStatus {
        if let healthStatus = healthStatus {
            return healthStatus
        }
        throw GenerationClientError.workerUnavailable(nil)
    }

    func fetchHardware() async throws -> WorkerHardwareProfile {
        if let hardwareProfile = hardwareProfile {
            return hardwareProfile
        }
        throw GenerationClientError.workerUnavailable(nil)
    }

    func fetchModels() async throws -> [ModelProfile] {
        return models
    }

    func submitTextToVideo(request: GenerationRequest) async throws -> String { return "job_123" }
    func submitImageToVideo(request: GenerationRequest) async throws -> String { return "job_123" }
    func submitAudioToVideo(request: GenerationRequest) async throws -> String { return "job_123" }
    func submitRetake(request: GenerationRequest) async throws -> String { return "job_123" }
    func getJobStatus(jobId: String) async throws -> GenerationJob {
        return GenerationJob(id: jobId, projectId: "test", sceneId: "test", status: .downloading)
    }
    func cancelJob(jobId: String) async throws {}
    func subscribeToJob(jobId: String) -> AsyncThrowingStream<ProgressEvent, Error> {
        return AsyncThrowingStream { continuation in
            continuation.yield(ProgressEvent(jobId: jobId, stage: "downloading", percentage: 0.5, message: "Downloading...", timestamp: ""))
            // Do not finish so it stays active
        }
    }
    func validateModelFolder(path: String) async throws -> ModelValidationResponse { fatalError("Not implemented") }
    func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse { fatalError("Not implemented") }
    func downloadModel(modelId: String) async throws -> ModelDownloadResponse { fatalError("Not implemented") }
    func deleteModel(modelId: String) async throws -> ModelDeleteResponse { fatalError("Not implemented") }
}
