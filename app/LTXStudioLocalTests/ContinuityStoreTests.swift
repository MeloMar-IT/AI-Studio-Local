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
}
