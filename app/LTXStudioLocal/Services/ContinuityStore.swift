import Foundation

public protocol ContinuityStore {
    func loadAll() throws -> [ContinuityElement]
    func save(_ element: ContinuityElement) throws
    func delete(elementId: String) throws
    func loadDefaultElements() throws
}

public enum ContinuityStoreError: Error {
    case directoryCreationFailed
    case encodingFailed(Error)
    case decodingFailed(Error)
    case fileWriteFailed(Error)
    case fileDeleteFailed(Error)
    case elementNotFound
}

public final class FileContinuityStore: ContinuityStore {
    private let fileManager: FileManager
    private let storeURL: URL
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    public init(fileManager: FileManager = .default, storeURL: URL? = nil) {
        self.fileManager = fileManager

        if let storeURL = storeURL {
            self.storeURL = storeURL
        } else {
            // Default to Application Support/AI Studio Local/ContinuityLibrary
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storeURL = appSupport.appendingPathComponent("AI Studio Local/ContinuityLibrary", isDirectory: true)
        }

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601

        try? ensureDirectoryExists()
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: storeURL.path) {
            do {
                try fileManager.createDirectory(at: storeURL, withIntermediateDirectories: true)
            } catch {
                throw ContinuityStoreError.directoryCreationFailed
            }
        }
    }

    public func loadAll() throws -> [ContinuityElement] {
        try ensureDirectoryExists()

        let fileURLs = try fileManager.contentsOfDirectory(at: storeURL, includingPropertiesForKeys: nil)
        let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }

        var elements: [ContinuityElement] = []
        for fileURL in jsonFiles {
            do {
                let data = try Data(contentsOf: fileURL)
                let element = try jsonDecoder.decode(ContinuityElement.self, from: data)
                elements.append(element)
            } catch {
                // If one fails, we log and continue
                print("Failed to decode continuity element at \(fileURL.path): \(error)")
            }
        }
        return elements
    }

    public func save(_ element: ContinuityElement) throws {
        try ensureDirectoryExists()

        let fileURL = storeURL.appendingPathComponent("\(element.id).json")
        do {
            let data = try jsonEncoder.encode(element)
            try data.write(to: fileURL)
        } catch let error as EncodingError {
            throw ContinuityStoreError.encodingFailed(error)
        } catch {
            throw ContinuityStoreError.fileWriteFailed(error)
        }
    }

    public func delete(elementId: String) throws {
        let fileURL = storeURL.appendingPathComponent("\(elementId).json")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw ContinuityStoreError.elementNotFound
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw ContinuityStoreError.fileDeleteFailed(error)
        }
    }

    public func loadDefaultElements() throws {
        let defaults: [ContinuityElement] = [
            ContinuityElement(
                type: .character,
                name: "Marcel",
                description: "Lead SRE with a focused expression",
                promptBlock: "A man in his late 30s, short dark hair, wearing a grey hoodie and glasses, focused look, sitting in front of monitors",
                tags: ["character", "sre"]
            ),
            ContinuityElement(
                type: .location,
                name: "Modern Office",
                description: "Clean, high-tech workspace",
                promptBlock: "A modern open-plan office with large windows, city skyline in the background, plants on desks, soft ambient lighting",
                tags: ["location", "office"]
            ),
            ContinuityElement(
                type: .style,
                name: "Cinematic Teal & Orange",
                description: "High contrast cinematic look",
                promptBlock: "cinematic style, teal and orange color grading, shallow depth of field, 4k, detailed textures",
                tags: ["style", "cinematic"]
            ),
            ContinuityElement(
                type: .camera,
                name: "Slow Dolly In",
                description: "Gradual movement towards subject",
                promptBlock: "slow dolly in, tracking shot, smooth camera movement",
                tags: ["camera", "movement"]
            )
        ]

        for element in defaults {
            try save(element)
        }
    }
}
