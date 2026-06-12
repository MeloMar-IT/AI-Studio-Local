import XCTest
@testable import LTXStudioLocal

final class ContinuityStoreTests: XCTestCase {
    var fileManager: FileManager!
    var store: FileContinuityStore!
    var tempDirectory: URL!

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

    func testSaveAndLoadElement() throws {
        let element = ContinuityElement(
            type: .character,
            name: "Test Character",
            promptBlock: "A test prompt"
        )

        try store.save(element)

        let loadedElements = try store.loadAll()
        XCTAssertEqual(loadedElements.count, 1)
        XCTAssertEqual(loadedElements.first?.id, element.id)
        XCTAssertEqual(loadedElements.first?.name, element.name)
        XCTAssertEqual(loadedElements.first?.type, .character)
    }

    func testDeleteElement() throws {
        let element = ContinuityElement(
            type: .location,
            name: "Test Location",
            promptBlock: "A test location prompt"
        )

        try store.save(element)
        XCTAssertEqual((try store.loadAll()).count, 1)

        try store.delete(elementId: element.id)
        XCTAssertEqual((try store.loadAll()).count, 0)
    }

    func testLoadDefaultElements() throws {
        try store.loadDefaultElements()

        let elements = try store.loadAll()
        XCTAssertGreaterThanOrEqual(elements.count, 4)

        let types = Set(elements.map { $0.type })
        XCTAssertTrue(types.contains(.character))
        XCTAssertTrue(types.contains(.location))
        XCTAssertTrue(types.contains(.style))
        XCTAssertTrue(types.contains(.camera))
    }

    func testValidateElement() throws {
        let element = ContinuityElement(
            type: .character,
            name: "Validation Test",
            promptBlock: "Validate me"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(element)

        let validated = try store.validateElement(from: data)
        XCTAssertEqual(validated.id, element.id)
        XCTAssertEqual(validated.name, element.name)
    }

    func testExport() throws {
        let elements = [
            ContinuityElement(type: .character, name: "E1", promptBlock: "P1"),
            ContinuityElement(type: .location, name: "E2", promptBlock: "P2")
        ]

        let exportDir = tempDirectory.appendingPathComponent("export")
        try store.export(elements: elements, to: exportDir)

        let files = try fileManager.contentsOfDirectory(at: exportDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 2)

        let fileNames = Set(files.map { $0.lastPathComponent })
        XCTAssertTrue(fileNames.contains("\(elements[0].id).json"))
        XCTAssertTrue(fileNames.contains("\(elements[1].id).json"))
    }
}
