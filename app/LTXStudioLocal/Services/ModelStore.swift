import Foundation
import Combine

public protocol ModelStore {
    func fetchModels() async throws -> [ModelProfile]
}

public final class RemoteModelStore: ModelStore {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://localhost:8000")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fetchModels() async throws -> [ModelProfile] {
        let url = baseURL.appendingPathComponent("models")

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return ModelProfile.mocks
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([ModelProfile].self, from: data)
        } catch {
            // Fallback to mocks if worker is offline or error occurs
            return ModelProfile.mocks
        }
    }
}
