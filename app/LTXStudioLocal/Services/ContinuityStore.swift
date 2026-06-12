import Foundation

public protocol ContinuityStore {
    func loadAll() throws -> [ContinuityElement]
    func loadAll(type: ContinuityElementType) throws -> [ContinuityElement]
    func save(_ element: ContinuityElement) throws
    func delete(elementId: String, type: ContinuityElementType) throws
    func search(query: String?, type: ContinuityElementType?, tags: [String]?) throws -> [ContinuityElement]
    func loadDefaultElements() throws
    func validateElement(from data: Data) throws -> ContinuityElement
    func importLibrary(from url: URL) throws
    func export(elements: [ContinuityElement], to url: URL) throws
}

public enum ContinuityStoreError: Error {
    case directoryCreationFailed
    case encodingFailed(Error)
    case decodingFailed(Error)
    case fileWriteFailed(Error)
    case fileDeleteFailed(Error)
    case elementNotFound
    case invalidSchema
    case assetMissing(String)
}

extension ContinuityElementType {
    var folderName: String {
        switch self {
        case .character: return "characters"
        case .location: return "locations"
        case .style: return "styles"
        case .camera: return "camera-presets"
        case .audio: return "audio-identities"
        case .brand: return "brand-kits"
        case .promptBlock: return "prompt-blocks"
        case .lora: return "loras"
        case .exportTemplate: return "export-templates"
        }
    }
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
            // Default to the one in UserSettings
            self.storeURL = UserSettings.shared.continuityLibraryURL
        }

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601

        try? ensureDirectoriesExist()
    }

    private func ensureDirectoriesExist() throws {
        for type in ContinuityElementType.allCases {
            let typeURL = storeURL.appendingPathComponent(type.folderName)
            if !fileManager.fileExists(atPath: typeURL.path) {
                do {
                    try fileManager.createDirectory(at: typeURL, withIntermediateDirectories: true)
                } catch {
                    throw ContinuityStoreError.directoryCreationFailed
                }
            }
        }
    }

    public func loadAll() throws -> [ContinuityElement] {
        var allElements: [ContinuityElement] = []
        for type in ContinuityElementType.allCases {
            let elements = try loadAll(type: type)
            allElements.append(contentsOf: elements)
        }
        return allElements
    }

    public func loadAll(type: ContinuityElementType) throws -> [ContinuityElement] {
        let typeURL = storeURL.appendingPathComponent(type.folderName)
        guard fileManager.fileExists(atPath: typeURL.path) else { return [] }

        let fileURLs = try fileManager.contentsOfDirectory(at: typeURL, includingPropertiesForKeys: nil)
        let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }

        var elements: [ContinuityElement] = []
        for fileURL in jsonFiles {
            do {
                let data = try Data(contentsOf: fileURL)
                let element = try jsonDecoder.decode(ContinuityElement.self, from: data)
                elements.append(element)
            } catch {
                print("Failed to decode continuity element at \(fileURL.path): \(error)")
            }
        }
        return elements
    }

    public func save(_ element: ContinuityElement) throws {
        try ensureDirectoriesExist()

        let fileURL = storeURL
            .appendingPathComponent(element.type.folderName)
            .appendingPathComponent("\(element.id).json")

        do {
            let data = try jsonEncoder.encode(element)
            try data.write(to: fileURL)
        } catch let error as EncodingError {
            throw ContinuityStoreError.encodingFailed(error)
        } catch {
            throw ContinuityStoreError.fileWriteFailed(error)
        }
    }

    public func delete(elementId: String, type: ContinuityElementType) throws {
        let fileURL = storeURL
            .appendingPathComponent(type.folderName)
            .appendingPathComponent("\(elementId).json")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw ContinuityStoreError.elementNotFound
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw ContinuityStoreError.fileDeleteFailed(error)
        }
    }

    public func search(query: String?, type: ContinuityElementType?, tags: [String]?) throws -> [ContinuityElement] {
        let elements: [ContinuityElement]
        if let type = type {
            elements = try loadAll(type: type)
        } else {
            elements = try loadAll()
        }

        return elements.filter { element in
            var matches = true

            if let query = query?.lowercased(), !query.isEmpty {
                let inName = element.name.lowercased().contains(query)
                let inDescription = element.description.lowercased().contains(query)
                let inTags = element.tags.contains { $0.lowercased().contains(query) }
                matches = matches && (inName || inDescription || inTags)
            }

            if let tags = tags, !tags.isEmpty {
                let hasTags = tags.allSatisfy { tag in
                    element.tags.contains { $0.lowercased() == tag.lowercased() }
                }
                matches = matches && hasTags
            }

            return matches
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
            ),
            BrandKit.mock.element
        ]

        for element in defaults {
            try save(element)
        }
    }

    public func validateElement(from data: Data) throws -> ContinuityElement {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let element = try decoder.decode(ContinuityElement.self, from: data)
            // Check assets
            for asset in element.assets {
                if !fileManager.fileExists(atPath: asset.path) {
                    print("Warning: Asset missing for \(element.name): \(asset.path)")
                }
            }
            return element
        } catch {
            throw ContinuityStoreError.invalidSchema
        }
    }

    public func importLibrary(from url: URL) throws {
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let element = try validateElement(from: data)
                    try save(element)
                } catch {
                    print("Import failed for \(fileURL.lastPathComponent): \(error)")
                }
            }
        }
    }

    public func export(elements: [ContinuityElement], to url: URL) throws {
        for element in elements {
            let typeURL = url.appendingPathComponent(element.type.folderName)
            if !fileManager.fileExists(atPath: typeURL.path) {
                try fileManager.createDirectory(at: typeURL, withIntermediateDirectories: true)
            }

            let fileURL = typeURL.appendingPathComponent("\(element.id).json")
            let data = try jsonEncoder.encode(element)
            try data.write(to: fileURL)
        }
    }
}
