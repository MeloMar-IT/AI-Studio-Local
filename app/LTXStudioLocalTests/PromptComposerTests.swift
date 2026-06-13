import XCTest
@testable import LTXStudioLocal

final class PromptComposerTests: XCTestCase {
    var composer: DefaultPromptComposer!

    override func setUp() {
        super.setUp()
        composer = DefaultPromptComposer()
    }

    func testComposeSimplePrompt() {
        let scene = Scene(name: "Test Scene", prompt: "A beautiful sunset")
        let result = composer.compose(scene: scene, elements: [])

        XCTAssertEqual(result.prompt, "A beautiful sunset")
        XCTAssertEqual(result.negativePrompt, "")
        XCTAssertTrue(result.sourceElementIds.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testComposeWithElements() {
        let scene = Scene(name: "Test Scene", prompt: "A man walking")
        let character = ContinuityElement(
            id: "char-1",
            type: .character,
            name: "Marcel",
            promptBlock: "wearing a grey hoodie"
        )
        let location = ContinuityElement(
            id: "loc-1",
            type: .location,
            name: "Office",
            promptBlock: "in a modern office"
        )

        let result = composer.compose(scene: scene, elements: [character, location])

        // Order: Scene Prompt, Character, Location
        XCTAssertEqual(result.prompt, "A man walking, wearing a grey hoodie, in a modern office")
        XCTAssertEqual(result.metadata["char-1"], "Marcel")
        XCTAssertEqual(result.metadata["loc-1"], "Office")
        XCTAssertEqual(result.sourceElementIds, ["char-1", "loc-1"])
    }

    func testStrictOrdering() {
        let scene = Scene(name: "Test Scene", prompt: "A man")

        let audio = ContinuityElement(id: "audio-1", type: .audio, name: "Audio", promptBlock: "lounge music")
        let style = ContinuityElement(id: "style-1", type: .style, name: "Style", promptBlock: "cinematic")
        let character = ContinuityElement(id: "char-1", type: .character, name: "Character", promptBlock: "a man")
        let camera = ContinuityElement(id: "camera-1", type: .camera, name: "Camera", promptBlock: "wide shot")
        let location = ContinuityElement(id: "loc-1", type: .location, name: "Location", promptBlock: "in Tokyo")

        // Provided in arbitrary order
        let elements = [audio, camera, style, location, character]
        let result = composer.compose(scene: scene, elements: elements)

        // Expected order: Scene, Character, Style, Location, Camera, Audio
        let expected = "A man, a man, cinematic, in Tokyo, wide shot, lounge music"
        XCTAssertEqual(result.prompt, expected)
    }

    func testDeduplication() {
        let scene = Scene(
            name: "Test Scene",
            prompt: "A beautiful sunset",
            negativePrompt: "low quality"
        )
        let style1 = ContinuityElement(
            id: "style-1",
            type: .style,
            name: "Style 1",
            promptBlock: "cinematic",
            negativePrompt: "blur"
        )
        let style2 = ContinuityElement(
            id: "style-2",
            type: .style,
            name: "Style 2",
            promptBlock: "cinematic", // Duplicate positive
            negativePrompt: "low quality" // Duplicate negative
        )

        let result = composer.compose(scene: scene, elements: [style1, style2])

        XCTAssertEqual(result.prompt, "A beautiful sunset, cinematic")
        XCTAssertEqual(result.negativePrompt, "low quality, blur")
    }

    func testEmptyPromptBlocks() {
        let scene = Scene(name: "Test Scene", prompt: "A man")
        let emptyElement = ContinuityElement(
            id: "empty-1",
            type: .style,
            name: "Empty",
            promptBlock: "  ",
            negativePrompt: ""
        )

        let result = composer.compose(scene: scene, elements: [emptyElement])

        XCTAssertEqual(result.prompt, "A man")
        XCTAssertEqual(result.negativePrompt, "")
        XCTAssertEqual(result.sourceElementIds, ["empty-1"])
    }

    func testWarningsForMissingElements() {
        let scene = Scene(
            name: "Test Scene",
            prompt: "A man",
            attachedContinuityElements: [
                AttachedContinuityElement(elementId: "missing-1", type: .character)
            ]
        )

        let result = composer.compose(scene: scene, elements: [])

        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertTrue(result.warnings[0].contains("Missing element"))
        XCTAssertTrue(result.warnings[0].contains("missing-1"))
    }

    func testDeterminism() {
        let scene = Scene(name: "Test Scene", prompt: "A man")
        let char1 = ContinuityElement(id: "char-a", type: .character, name: "A", promptBlock: "a")
        let char2 = ContinuityElement(id: "char-b", type: .character, name: "B", promptBlock: "b")

        let result1 = composer.compose(scene: scene, elements: [char1, char2])
        let result2 = composer.compose(scene: scene, elements: [char2, char1])

        XCTAssertEqual(result1.prompt, result2.prompt)
        XCTAssertEqual(result1.sourceElementIds, result2.sourceElementIds)
    }

    func testConsistencyLocks() {
        var scene = Scene(name: "Test Scene", prompt: "A man")
        scene.consistencyLocks.characterIdentity = true
        scene.consistencyLocks.seed = true

        let result = composer.compose(scene: scene, elements: [])

        XCTAssertEqual(result.metadata["lock_character"], "true")
        XCTAssertEqual(result.metadata["lock_seed"], "true")
        XCTAssertNil(result.metadata["lock_location"])
    }
}
