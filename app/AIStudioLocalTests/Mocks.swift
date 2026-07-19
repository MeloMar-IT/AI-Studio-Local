import Foundation
import Combine
@testable import AIStudioLocal

class MockHardwareProfiler: HardwareProfilerProtocol {
    var profile = HardwareProfile(
        modelName: "Mock MacBook Pro",
        isAppleSilicon: true,
        totalMemoryGB: 64,
        generationProfile: .recommended,
        isLocalModeReady: true
    )

    func getHardwareProfile() async -> HardwareProfile {
        return profile
    }
}

class MockWorkerManager: WorkerManagerProtocol, ObservableObject {
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
        return WorkerHardwareProfile(
            device: "mock",
            chip: "Apple M2",
            totalMemoryGb: 64,
            freeMemoryGb: 32,
            osName: "macOS",
            osVersion: "14.0",
            pythonPath: "/usr/bin/python3",
            venvPath: "/path/to/venv",
            librariesStatus: ["mlx": true],
            mlxAvailable: true,
            pytorchAvailable: true,
            ffmpegAvailable: true,
            freeDiskModelsGb: 100,
            freeDiskOutputs_Gb: 50,
            status: "ready",
            messages: []
        )
    }

    func fetchModels() async throws -> [ModelProfile] {
        return models
    }

    func submitTextToVideo(request: GenerationRequest) async throws -> String { return "job-1" }
    func submitImageToVideo(request: GenerationRequest) async throws -> String { return "job-1" }
    func submitAudioToVideo(request: GenerationRequest) async throws -> String { return "job-1" }
    func submitVoiceClone(request: GenerationRequest) async throws -> String { return "job-1" }
    func submitRetake(request: GenerationRequest) async throws -> String { return "job-1" }

    func getJobStatus(jobId: String) async throws -> GenerationJob {
        return GenerationJob(projectId: "p1", sceneId: "s1")
    }

    func cancelJob(jobId: String) async throws {}

    func subscribeToJob(jobId: String) -> AsyncThrowingStream<ProgressEvent, Error> {
        return AsyncThrowingStream { $0.finish() }
    }

    func validateModelFolder(path: String) async throws -> ModelValidationResponse {
        return ModelValidationResponse(matchedProfile: nil, missingFiles: [], warnings: [], canUse: true, message: "OK")
    }

    func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse {
        return ModelImportResponse(success: true, message: "OK", targetPath: nil)
    }

    func downloadModel(modelId: String) async throws -> ModelDownloadResponse {
        return ModelDownloadResponse(success: true, message: "OK", jobId: "j1", modelId: modelId)
    }

    func deleteModel(modelId: String) async throws -> ModelDeleteResponse {
        return ModelDeleteResponse(success: true, message: "OK")
    }
}
