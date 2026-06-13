import Foundation
import Combine

public protocol ModelStore {
    func fetchModels() async throws -> [ModelProfile]
    func validateModelFolder(path: String) async throws -> ModelValidationResponse
    func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse
}

public final class RemoteModelStore: ModelStore {
    private let generationClient: GenerationClient

    public init(generationClient: GenerationClient = HTTPGenerationClient()) {
        self.generationClient = generationClient
    }

    public func fetchModels() async throws -> [ModelProfile] {
        do {
            return try await generationClient.fetchModels()
        } catch {
            // Fallback to mocks if worker is offline or error occurs
            return ModelProfile.mocks
        }
    }

    public func validateModelFolder(path: String) async throws -> ModelValidationResponse {
        return try await generationClient.validateModelFolder(path: path)
    }

    public func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse {
        return try await generationClient.importModel(path: path, copy: copy, modelId: modelId)
    }
}
