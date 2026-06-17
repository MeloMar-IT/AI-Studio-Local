import XCTest
import Combine
@testable import LTXStudioLocal

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
        // 1. Initially offline
        XCTAssertEqual(appState.workerStatus, .stopped)

        // 2. Start worker
        await appState.startWorker()
        XCTAssertEqual(mockWorkerManager.startWorkerCallCount, 1)

        // 3. Simulate process starting
        mockWorkerManager.status = .starting

        // Wait for AppState to observe status change
        let expectation = XCTestExpectation(description: "AppState observes starting status")
        appState.$workerStatus
            .sink { status in
                if status == .starting {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(appState.workerStatus, .starting)

        // 4. Simulate health check passing
        mockGenerationClient.healthStatus = HealthStatus(status: "ok", version: "1.0.0", uptime: 10.0)
        await appState.checkWorkerHealth()

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
    func getJobStatus(jobId: String) async throws -> GenerationJob { fatalError("Not implemented") }
    func cancelJob(jobId: String) async throws {}
    func subscribeToJob(jobId: String) -> AsyncThrowingStream<ProgressEvent, Error> { fatalError("Not implemented") }
    func validateModelFolder(path: String) async throws -> ModelValidationResponse { fatalError("Not implemented") }
    func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse { fatalError("Not implemented") }
    func downloadModel(modelId: String) async throws -> ModelDownloadResponse { fatalError("Not implemented") }
}
