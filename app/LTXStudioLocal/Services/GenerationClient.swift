import Foundation

public protocol GenerationClient {
    func checkHealth() async throws -> HealthStatus
    func fetchModels() async throws -> [ModelProfile]
    func submitTextToVideo(request: GenerationRequest) async throws -> String // returns job_id
    func submitImageToVideo(request: GenerationRequest) async throws -> String // returns job_id
    func getJobStatus(jobId: String) async throws -> GenerationJob
    func cancelJob(jobId: String) async throws
}

public enum GenerationClientError: Error {
    case workerUnavailable(Error?)
    case jobNotFound(String)
    case invalidRequest(String)
    case workerError(String)
    case decodingError(Error)

    public var asAppError: AppError {
        switch self {
        case .workerUnavailable(let error):
            return AppError.workerUnavailable(error: error)
        case .workerError(let message):
            return AppError.generationFailed(details: message)
        case .invalidRequest(let message):
            return AppError.generationFailed(details: "Invalid request: \(message)")
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
        imagePath: String? = nil
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
    }
}

public final class HTTPGenerationClient: GenerationClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(baseURL: URL = URL(string: "http://localhost:8000")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    public func checkHealth() async throws -> HealthStatus {
        let url = baseURL.appendingPathComponent("health")
        do {
            let (data, _) = try await session.data(from: url)
            return try decoder.decode(HealthStatus.self, from: data)
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

    private func submitGeneration(request: GenerationRequest, endpoint: String) async throws -> String {
        let url = baseURL.appendingPathComponent(endpoint)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            urlRequest.httpBody = try encoder.encode(request)

            let (data, response) = try await session.data(for: urlRequest)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 400 {
                throw GenerationClientError.invalidRequest("Server returned 400")
            }

            struct JobResponse: Codable {
                let jobId: String
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
                throw GenerationClientError.workerError("Failed to cancel job")
            }
        } catch let error as GenerationClientError {
            throw error
        } catch {
            throw GenerationClientError.workerUnavailable(error)
        }
    }
}
