import Foundation

public protocol GenerationClient {
    func checkHealth() async throws -> HealthStatus
    func fetchHardware() async throws -> WorkerHardwareProfile
    func fetchModels() async throws -> [ModelProfile]
    func submitTextToVideo(request: GenerationRequest) async throws -> String // returns job_id
    func submitImageToVideo(request: GenerationRequest) async throws -> String // returns job_id
    func submitAudioToVideo(request: GenerationRequest) async throws -> String // returns job_id
    func submitRetake(request: GenerationRequest) async throws -> String // returns job_id
    func getJobStatus(jobId: String) async throws -> GenerationJob
    func cancelJob(jobId: String) async throws
    func subscribeToJob(jobId: String) -> AsyncThrowingStream<ProgressEvent, Error>
    func validateModelFolder(path: String) async throws -> ModelValidationResponse
    func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse
    func downloadModel(modelId: String) async throws -> ModelDownloadResponse
}

public struct WorkerHardwareProfile: Codable, Equatable {
    public let device: String
    public let chip: String
    public let totalMemoryGb: Double
    public let freeMemoryGb: Double
    public let osName: String
    public let osVersion: String
    public let mlxAvailable: Bool
    public let status: String
    public let messages: [String]

    enum CodingKeys: String, CodingKey {
        case device
        case chip
        case totalMemoryGb = "total_memory_gb"
        case freeMemoryGb = "free_memory_gb"
        case osName = "os_name"
        case osVersion = "os_version"
        case mlxAvailable = "mlx_available"
        case status
        case messages
    }
}

public struct ModelValidationResponse: Codable {
    public let matchedProfile: ModelProfile?
    public let missingFiles: [String]
    public let warnings: [String]
    public let canUse: Bool
    public let message: String

    enum CodingKeys: String, CodingKey {
        case matchedProfile = "matched_profile"
        case missingFiles = "missing_files"
        case warnings
        case canUse = "can_use"
        case message
    }
}

public struct ModelImportResponse: Codable {
    public let success: Bool
    public let message: String
    public let targetPath: String?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case targetPath = "target_path"
    }
}

public struct ProgressEvent: Codable {
    public let jobId: String
    public let stage: String
    public let percentage: Double?
    public let message: String
    public let timestamp: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case stage
        case percentage
        case message
        case timestamp
    }
}

public enum GenerationClientError: Error {
    case workerUnavailable(Error?)
    case workerUnhealthy(String)
    case jobNotFound(String)
    case invalidRequest(String)
    case workerError(code: String, message: String, action: String? = nil)
    case decodingError(Error)
    case unsupportedCapability(String)
    case missingModel(String)

    public var asAppError: AppError {
        switch self {
        case .workerUnavailable(let error):
            return AppError.workerUnavailable(error: error)
        case .workerUnhealthy(let message):
            return AppError(
                title: "Worker Unhealthy",
                message: "The worker is running but reported an issue: \(message)",
                suggestedActions: ["Check worker logs", "Restart the worker"]
            )
        case .workerError(let code, let message, let action):
            if code == "insufficient_memory" {
                return AppError.insufficientMemory()
            }
            if code == "mlx_missing" {
                return AppError.mlxMissing()
            }
            if code == "ffmpeg_missing" {
                return AppError.ffmpegMissing()
            }
            if code == "unsupported_mac" {
                return AppError.unsupportedMac(reason: message)
            }
            if code == "generation_cancelled" {
                return AppError.generationCancelled()
            }

            var actions = ["Check worker logs"]
            if let action = action {
                actions.append(action)
            }
            return AppError(
                title: "Worker Error",
                message: message,
                technicalDetails: "Error code: \(code)",
                suggestedActions: actions
            )
        case .invalidRequest(let message):
            return AppError.generationFailed(details: "Invalid request: \(message)")
        case .unsupportedCapability(let capability):
            return AppError.generationUnsupported(reason: "This feature (\(capability)) is not supported by the current model.")
        case .missingModel(let modelId):
            return AppError.modelNotInstalled(modelName: modelId)
        case .decodingError(let error):
            return AppError.generationFailed(details: "Failed to parse worker response: \(error.localizedDescription)")
        default:
            return AppError.generationFailed(details: self.localizedDescription)
        }
    }
}

public struct HealthStatus: Codable {
    public let status: String
    public let version: String
    public let uptime: Double
}

public struct GenerationRequest: Codable {
    public let prompt: String
    public let negativePrompt: String?
    public let width: Int
    public let height: Int
    public let numFrames: Int
    public let steps: Int
    public let guidanceScale: Double
    public let seed: Int?
    public let modelId: String
    public let projectId: String
    public let sceneId: String
    public let imagePath: String?
    public let audioPath: String?
    public let videoPath: String?
    public let retakeStartSeconds: Double?
    public let retakeEndSeconds: Double?

    public init(
        prompt: String,
        negativePrompt: String? = nil,
        width: Int = 704,
        height: Int = 480,
        numFrames: Int = 161,
        steps: Int = 20,
        guidanceScale: Double = 3.0,
        seed: Int? = nil,
        modelId: String,
        projectId: String,
        sceneId: String,
        imagePath: String? = nil,
        audioPath: String? = nil,
        videoPath: String? = nil,
        retakeStartSeconds: Double? = nil,
        retakeEndSeconds: Double? = nil
    ) {
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.width = width
        self.height = height
        self.numFrames = numFrames
        self.steps = steps
        self.guidanceScale = guidanceScale
        self.seed = seed
        self.modelId = modelId
        self.projectId = projectId
        self.sceneId = sceneId
        self.imagePath = imagePath
        self.audioPath = audioPath
        self.videoPath = videoPath
        self.retakeStartSeconds = retakeStartSeconds
        self.retakeEndSeconds = retakeEndSeconds
    }

    enum CodingKeys: String, CodingKey {
        case prompt
        case negativePrompt = "negative_prompt"
        case width
        case height
        case numFrames = "num_frames"
        case steps
        case guidanceScale = "guidance_scale"
        case seed
        case modelId = "model_id"
        case projectId = "project_id"
        case sceneId = "scene_id"
        case imagePath = "image_path"
        case audioPath = "audio_path"
        case videoPath = "video_path"
        case retakeStartSeconds = "retake_start_seconds"
        case retakeEndSeconds = "retake_end_seconds"
    }
}

public final class HTTPGenerationClient: GenerationClient {
    private var baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(baseURL: URL = URL(string: "http://localhost:8000")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        // We use explicit CodingKeys in our domain models to match the worker's snake_case
        self.decoder.keyDecodingStrategy = .useDefaultKeys
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    public func updateBaseURL(_ url: URL) {
        self.baseURL = url
    }

    public func checkHealth() async throws -> HealthStatus {
        let url = baseURL.appendingPathComponent("health")
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw GenerationClientError.workerUnhealthy("Server returned non-200 status")
            }
            return try decoder.decode(HealthStatus.self, from: data)
        } catch let error as GenerationClientError {
            throw error
        } catch {
            throw GenerationClientError.workerUnavailable(error)
        }
    }

    public func fetchHardware() async throws -> WorkerHardwareProfile {
        let url = baseURL.appendingPathComponent("hardware")
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw GenerationClientError.workerError(code: "hardware_fetch_failed", message: "Failed to fetch hardware profile")
            }
            return try decoder.decode(WorkerHardwareProfile.self, from: data)
        } catch {
            throw GenerationClientError.workerUnavailable(error)
        }
    }

    public func fetchModels() async throws -> [ModelProfile] {
        let url = baseURL.appendingPathComponent("models")
        do {
            let (data, _) = try await session.data(from: url)

            struct ModelsResponse: Codable {
                let models: [ModelProfile]
            }

            let response = try decoder.decode(ModelsResponse.self, from: data)
            return response.models
        } catch {
            throw GenerationClientError.workerUnavailable(error)
        }
    }

    public func submitTextToVideo(request: GenerationRequest) async throws -> String {
        return try await submitGeneration(request: request, endpoint: "generate/text-to-video")
    }

    public func submitImageToVideo(request: GenerationRequest) async throws -> String {
        return try await submitGeneration(request: request, endpoint: "generate/image-to-video")
    }

    public func submitAudioToVideo(request: GenerationRequest) async throws -> String {
        return try await submitGeneration(request: request, endpoint: "generate/audio-to-video")
    }

    public func submitRetake(request: GenerationRequest) async throws -> String {
        return try await submitGeneration(request: request, endpoint: "generate/retake")
    }

    private func submitGeneration(request: GenerationRequest, endpoint: String) async throws -> String {
        let url = baseURL.appendingPathComponent(endpoint)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            urlRequest.httpBody = try encoder.encode(request)

            let (data, response) = try await session.data(for: urlRequest)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                // Try to parse structured error
                struct WorkerErrorResponse: Codable {
                    struct ErrorDetail: Codable {
                        let code: String
                        let message: String
                        let action: String?
                    }
                    let error: ErrorDetail
                }

                if let workerError = try? decoder.decode(WorkerErrorResponse.self, from: data) {
                    let code = workerError.error.code
                    let msg = workerError.error.message
                    let action = workerError.error.action

                    if code == "unsupported_capability" {
                        throw GenerationClientError.unsupportedCapability(msg)
                    }
                    if code == "model_not_found" || code == "model_not_installed" {
                        throw GenerationClientError.missingModel(request.modelId)
                    }
                    throw GenerationClientError.workerError(code: code, message: msg, action: action)
                }

                throw GenerationClientError.workerError(code: "http_\(httpResponse.statusCode)", message: "Server returned \(httpResponse.statusCode)")
            }

            struct JobResponse: Codable {
                let jobId: String

                enum CodingKeys: String, CodingKey {
                    case jobId = "job_id"
                }
            }

            let responseData = try decoder.decode(JobResponse.self, from: data)
            return responseData.jobId
        } catch let error as GenerationClientError {
            throw error
        } catch {
            throw GenerationClientError.workerUnavailable(error)
        }
    }

    public func getJobStatus(jobId: String) async throws -> GenerationJob {
        let url = baseURL.appendingPathComponent("jobs/\(jobId)")
        do {
            let (data, response) = try await session.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                throw GenerationClientError.jobNotFound(jobId)
            }

            // The worker returns a slightly different structure for job status
            // we need to map it to our GenerationJob domain model
            struct WorkerJobStatus: Codable {
                let jobId: String
                let status: String
                let progress: Double
                let message: String
                let resultUrl: String?
                let error: String?
                let projectId: String?
                let sceneId: String?
                let startedAt: Date?
                let completedAt: Date?
            }

            let workerStatus = try decoder.decode(WorkerJobStatus.self, from: data)

            return GenerationJob(
                id: workerStatus.jobId,
                projectId: workerStatus.projectId ?? "unknown",
                sceneId: workerStatus.sceneId ?? "unknown",
                status: JobStatus(rawValue: workerStatus.status) ?? .queued,
                progress: workerStatus.progress,
                startedAt: workerStatus.startedAt,
                completedAt: workerStatus.completedAt,
                outputPaths: workerStatus.resultUrl.map { JobOutputPaths(video: $0) },
                errorInformation: workerStatus.error.map { JobErrorInformation(code: "worker_error", message: $0) }
            )
        } catch let error as GenerationClientError {
            throw error
        } catch {
            throw GenerationClientError.workerUnavailable(error)
        }
    }

    public func cancelJob(jobId: String) async throws {
        let url = baseURL.appendingPathComponent("jobs/\(jobId)/cancel")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        do {
            let (_, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw GenerationClientError.workerError(code: "cancel_failed", message: "Failed to cancel job")
            }
        } catch let error as GenerationClientError {
            throw error
        } catch {
            throw GenerationClientError.workerUnavailable(error)
        }
    }

    public func subscribeToJob(jobId: String) -> AsyncThrowingStream<ProgressEvent, Error> {
        let url = baseURL.appendingPathComponent("jobs/\(jobId)/events")

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: URLRequest(url: url))

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: GenerationClientError.workerError(code: "event_stream_failed", message: "Failed to connect to event stream"))
                        return
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if let data = jsonString.data(using: .utf8) {
                                let event = try decoder.decode(ProgressEvent.self, from: data)
                                continuation.yield(event)

                                // Terminal stages
                                let terminalStages = ["completed", "failed", "cancelled", "interrupted"]
                                if terminalStages.contains(event.stage) {
                                    continuation.finish()
                                    return
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func validateModelFolder(path: String) async throws -> ModelValidationResponse {
        let url = baseURL.appendingPathComponent("models/validate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct ValidationRequest: Encodable {
            let path: String
        }

        urlRequest.httpBody = try encoder.encode(ValidationRequest(path: path))

        let (data, _) = try await session.data(for: urlRequest)
        return try decoder.decode(ModelValidationResponse.self, from: data)
    }

    public func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse {
        let url = baseURL.appendingPathComponent("models/import")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct ImportRequest: Encodable {
            let path: String
            let copyFiles: Bool
            let modelId: String?

            enum CodingKeys: String, CodingKey {
                case path
                case copyFiles = "copy_files"
                case modelId = "model_id"
            }
        }

        urlRequest.httpBody = try encoder.encode(ImportRequest(path: path, copyFiles: copy, modelId: modelId))

        let (data, response) = try await session.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            // Try to decode error message
            struct WorkerError: Decodable {
                let detail: String
            }
            if let error = try? decoder.decode(WorkerError.self, from: data) {
                throw GenerationClientError.workerError(code: "import_failed", message: error.detail)
            }
            throw GenerationClientError.workerError(code: "http_\(httpResponse.statusCode)", message: "Server returned \(httpResponse.statusCode)")
        }

        return try decoder.decode(ModelImportResponse.self, from: data)
    }

    public func downloadModel(modelId: String) async throws -> ModelDownloadResponse {
        let url = baseURL.appendingPathComponent("models/download")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct DownloadRequest: Encodable {
            let modelId: String

            enum CodingKeys: String, CodingKey {
                case modelId = "model_id"
            }
        }

        urlRequest.httpBody = try encoder.encode(DownloadRequest(modelId: modelId))

        let (data, response) = try await session.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            struct WorkerError: Decodable {
                let detail: String
            }
            if let error = try? decoder.decode(WorkerError.self, from: data) {
                throw GenerationClientError.workerError(code: "download_failed", message: error.detail)
            }
            throw GenerationClientError.workerError(code: "http_\(httpResponse.statusCode)", message: "Server returned \(httpResponse.statusCode)")
        }

        return try decoder.decode(ModelDownloadResponse.self, from: data)
    }
}
