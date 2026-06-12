import Foundation
import Combine

public protocol ModelStore {
    func fetchModels() async throws -> [ModelProfile]
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
}
