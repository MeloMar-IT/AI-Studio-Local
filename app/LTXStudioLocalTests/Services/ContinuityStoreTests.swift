import XCTest
@testable import LTXStudioLocal

final class ContinuityStoreTests: XCTestCase {
    var fileManager: FileManager!
    var tempDirectory: URL!
    var store: FileContinuityStore!

    override func setUp() {
        super.setUp()
        fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        store = FileContinuityStore(fileManager: fileManager, storeURL: tempDirectory)
    }

    override func tearDown() {
        try? fileManager.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testCreateAndLoadElement() throws {
        let element = ContinuityElement(
            type: .character,
            name: "Test Character",
            promptBlock: "Test prompt",
            tags: ["test", "character"]
        )

        try store.save(element)

        let loadedElements = try store.loadAll(type: .character)
        XCTAssertEqual(loadedElements.count, 1)
        XCTAssertEqual(loadedElements.first?.name, "Test Character")
        XCTAssertEqual(loadedElements.first?.type, .character)

        // Verify folder structure
        let expectedFolder = tempDirectory.appendingPathComponent("characters")
        XCTAssertTrue(fileManager.fileExists(atPath: expectedFolder.path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedFolder.appendingPathComponent("\(element.id).json").path))
    }

    func testEditElement() throws {
        var element = ContinuityElement(
            type: .location,
            name: "Initial Location",
            promptBlock: "Initial prompt"
        )
        try store.save(element)

        element.name = "Updated Location"
        try store.save(element)

        let loadedElements = try store.loadAll(type: .location)
        XCTAssertEqual(loadedElements.count, 1)
        XCTAssertEqual(loadedElements.first?.name, "Updated Location")
    }

    func testDeleteElement() throws {
        let element = ContinuityElement(
            type: .style,
            name: "Delete Me",
            promptBlock: "Style prompt"
        )
        try store.save(element)
        XCTAssertEqual(try store.loadAll(type: .style).count, 1)

        try store.delete(elementId: element.id, type: .style)
        XCTAssertEqual(try store.loadAll(type: .style).count, 0)
    }

    func testSearch() throws {
        let char1 = ContinuityElement(type: .character, name: "Alice", description: "Wonderland", promptBlock: "p1", tags: ["girl"])
        let char2 = ContinuityElement(type: .character, name: "Bob", description: "Builder", promptBlock: "p2", tags: ["man"])
        let loc1 = ContinuityElement(type: .location, name: "Garden", description: "Green", promptBlock: "p3", tags: ["nature"])

        try store.save(char1)
        try store.save(char2)
        try store.save(loc1)

        // Search by name
        let nameResults = try store.search(query: "Alice", type: nil, tags: nil)
        XCTAssertEqual(nameResults.count, 1)
        XCTAssertEqual(nameResults.first?.name, "Alice")

        // Search by description
        let descResults = try store.search(query: "Builder", type: nil, tags: nil)
        XCTAssertEqual(descResults.count, 1)
        XCTAssertEqual(descResults.first?.name, "Bob")

        // Search by tag
        let tagResults = try store.search(query: nil, type: nil, tags: ["nature"])
        XCTAssertEqual(tagResults.count, 1)
        XCTAssertEqual(tagResults.first?.name, "Garden")

        // Search by type
        let typeResults = try store.search(query: nil, type: .character, tags: nil)
        XCTAssertEqual(typeResults.count, 2)
    }

    func testImportExport() throws {
        let element = ContinuityElement(type: .camera, name: "Export Test", promptBlock: "p")
        try store.save(element)

        let exportDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try store.export(elements: [element], to: exportDir)

        // Verify exported file exists in correct subfolder
        XCTAssertTrue(fileManager.fileExists(atPath: exportDir.appendingPathComponent("camera-presets").appendingPathComponent("\(element.id).json").path))

        // Create a new store and import
        let newTempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let newStore = FileContinuityStore(fileManager: fileManager, storeURL: newTempDir)

        try newStore.importLibrary(from: exportDir)
        let importedElements = try newStore.loadAll(type: .camera)
        XCTAssertEqual(importedElements.count, 1)
        XCTAssertEqual(importedElements.first?.name, "Export Test")

        try? fileManager.removeItem(at: exportDir)
        try? fileManager.removeItem(at: newTempDir)
    }

    func testInvalidSchema() throws {
        let invalidData = "{\"invalid\": \"json\"}".data(using: .utf8)!
        XCTAssertThrowsError(try store.validateElement(from: invalidData)) { error in
            XCTAssertEqual(error as? ContinuityStoreError, .invalidSchema)
        }
    }

    func testMissingAssetWarning() throws {
        let missingAsset = ContinuityAsset(path: "/non/existent/path", type: "image")
        let element = ContinuityElement(
            type: .character,
            name: "Asset Test",
            promptBlock: "p",
            assets: [missingAsset]
        )

        // This should not throw, but print a warning (which we can't easily test in unit tests without a logger mock)
        // We just ensure it returns the element correctly.
        // Use the same encoder settings as the store
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(element)
        let validated = try store.validateElement(from: data)
        XCTAssertEqual(validated.name, "Asset Test")
        XCTAssertEqual(validated.assets.count, 1)
    }
}

extension ContinuityStoreError: Equatable {
    public static func == (lhs: ContinuityStoreError, rhs: ContinuityStoreError) -> Bool {
        switch (lhs, rhs) {
        case (.directoryCreationFailed, .directoryCreationFailed): return true
        case (.elementNotFound, .elementNotFound): return true
        case (.invalidSchema, .invalidSchema): return true
        default: return false
        }
    }
}
