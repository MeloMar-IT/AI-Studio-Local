import XCTest
@testable import AIStudioLocal

final class SceneResolutionTests: XCTestCase {
    var fileManager: FileManager!
    var tempDirectory: URL!
    var continuityStore: FileContinuityStore!
    var sceneResolver: DefaultSceneResolver!

    override func setUp() {
        super.setUp()
        fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        continuityStore = FileContinuityStore(fileManager: fileManager, storeURL: tempDirectory)
        sceneResolver = DefaultSceneResolver(continuityStore: continuityStore)
    }

    override func tearDown() {
        try? fileManager.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testResolveExistingElements() throws {
        // 1. Create and save continuity elements
        let charElement = ContinuityElement(type: .character, name: "Alice", promptBlock: "Alice prompt")
        let locElement = ContinuityElement(type: .location, name: "Garden", promptBlock: "Garden prompt")
        try continuityStore.save(charElement)
        try continuityStore.save(locElement)

        // 2. Create scene referencing these elements
        let scene = Scene(
            name: "Test Scene",
            attachedContinuityElements: [
                AttachedContinuityElement(elementId: charElement.id, type: .character),
                AttachedContinuityElement(elementId: locElement.id, type: .location)
            ]
        )

        // 3. Resolve
        let resolved = try sceneResolver.resolve(scene: scene)

        // 4. Verify
        XCTAssertEqual(resolved.count, 2)
        XCTAssertFalse(resolved[0].isMissing)
        XCTAssertEqual(resolved[0].element?.id, charElement.id)
        XCTAssertFalse(resolved[1].isMissing)
        XCTAssertEqual(resolved[1].element?.id, locElement.id)
    }

    func testResolveMissingElements() throws {
        // 1. Create scene referencing non-existent elements
        let missingId = "missing-123"
        let scene = Scene(
            name: "Test Scene",
            attachedContinuityElements: [
                AttachedContinuityElement(elementId: missingId, type: .character)
            ]
        )

        // 2. Resolve
        let resolved = try sceneResolver.resolve(scene: scene)

        // 3. Verify
        XCTAssertEqual(resolved.count, 1)
        XCTAssertTrue(resolved[0].isMissing)
        XCTAssertNil(resolved[0].element)
        XCTAssertEqual(resolved[0].reference.elementId, missingId)
    }

    func testConsistencyLocksPersistence() throws {
        let locks = ConsistencyLocks(
            characterIdentity: true,
            location: false,
            style: true,
            brand: false,
            audioIdentity: true,
            seed: true,
            clothing: true,
            camera: false
        )

        let scene = Scene(name: "Lock Test", consistencyLocks: locks)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(scene)

        // Verify JSON keys (manual check or decode back)
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("character_identity"))
        XCTAssertTrue(jsonString.contains("audio_identity"))

        let decoder = JSONDecoder()
        let decodedScene = try decoder.decode(Scene.self, from: data)

        XCTAssertEqual(decodedScene.consistencyLocks.characterIdentity, true)
        XCTAssertEqual(decodedScene.consistencyLocks.location, false)
        XCTAssertEqual(decodedScene.consistencyLocks.audioIdentity, true)
        XCTAssertEqual(decodedScene.consistencyLocks.seed, true)
        XCTAssertEqual(decodedScene.consistencyLocks.clothing, true)
    }
}
