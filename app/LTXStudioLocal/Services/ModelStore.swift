import Foundation
import Combine

public protocol ModelStore {
    func fetchModels() async throws -> [ModelProfile]
    func validateModelFolder(path: String) async throws -> ModelValidationResponse
    func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse
    func downloadModel(modelId: String) async throws -> ModelDownloadResponse
}

public struct ModelDownloadResponse: Codable {
    public let success: Bool
    public let message: String
    public let jobId: String?
    public let modelId: String?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case jobId = "job_id"
        case modelId = "model_id"
    }
}

public final class RemoteModelStore: ModelStore {
    private let generationClient: GenerationClient

    public init(generationClient: GenerationClient = HTTPGenerationClient()) {
        self.generationClient = generationClient
    }

    public func fetchModels() async throws -> [ModelProfile] {
        return try await generationClient.fetchModels()
    }

    public func validateModelFolder(path: String) async throws -> ModelValidationResponse {
        return try await generationClient.validateModelFolder(path: path)
    }

    public func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse {
        return try await generationClient.importModel(path: path, copy: copy, modelId: modelId)
    }

    public func downloadModel(modelId: String) async throws -> ModelDownloadResponse {
        return try await generationClient.downloadModel(modelId: modelId)
    }
}
