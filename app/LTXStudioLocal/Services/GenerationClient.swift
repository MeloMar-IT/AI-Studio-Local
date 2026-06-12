import Foundation

public protocol GenerationClient {
    func checkHealth() async throws -> HealthStatus
    func fetchModels() async throws -> [ModelProfile]
    func submitTextToVideo(request: GenerationRequest) async throws -> String // returns job_id
    func getJobStatus(jobId: String) async throws -> GenerationJob
    func cancelJob(jobId: String) async throws
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
        sceneId: String
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
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(HealthStatus.self, from: data)
    }

    public func fetchModels() async throws -> [ModelProfile] {
        let url = baseURL.appendingPathComponent("models")
        let (data, _) = try await session.data(from: url)

        struct ModelsResponse: Codable {
            let models: [ModelProfile]
        }

        let response = try decoder.decode(ModelsResponse.self, from: data)
        return response.models
    }

    public func submitTextToVideo(request: GenerationRequest) async throws -> String {
        let url = baseURL.appendingPathComponent("generate/text-to-video")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, _) = try await session.data(for: urlRequest)

        struct JobResponse: Codable {
            let jobId: String
        }

        let response = try decoder.decode(JobResponse.self, from: data)
        return response.jobId
    }

    public func getJobStatus(jobId: String) async throws -> GenerationJob {
        let url = baseURL.appendingPathComponent("jobs/\(jobId)")
        let (data, _) = try await session.data(from: url)

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
    }

    public func cancelJob(jobId: String) async throws {
        let url = baseURL.appendingPathComponent("jobs/\(jobId)/cancel")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GenerationClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to cancel job"])
        }
    }
}
