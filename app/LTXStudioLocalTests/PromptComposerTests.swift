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
        XCTAssertTrue(result.metadata.isEmpty)
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
    }

    func testComposeWithNegativePrompts() {
        let scene = Scene(
            name: "Test Scene",
            prompt: "A man walking",
            negativePrompt: "low quality"
        )
        let character = ContinuityElement(
            id: "char-1",
            type: .character,
            name: "Marcel",
            promptBlock: "wearing a grey hoodie",
            negativePrompt: "blur"
        )

        let result = composer.compose(scene: scene, elements: [character])

        XCTAssertEqual(result.prompt, "A man walking, wearing a grey hoodie")
        XCTAssertEqual(result.negativePrompt, "low quality, blur")
    }

    func testComposeWithLocks() {
        var scene = Scene(name: "Test Scene", prompt: "A man walking")
        scene.consistencyLocks.character = true
        scene.consistencyLocks.seed = true

        let result = composer.compose(scene: scene, elements: [])

        XCTAssertEqual(result.metadata["lock_character"], "true")
        XCTAssertEqual(result.metadata["lock_seed"], "true")
        XCTAssertNil(result.metadata["lock_location"])
    }

    func testElementOrdering() {
        let scene = Scene(name: "Test Scene", prompt: "A man walking")
        let style = ContinuityElement(type: .style, name: "Style", promptBlock: "cinematic")
        let character = ContinuityElement(type: .character, name: "Character", promptBlock: "a man")
        let camera = ContinuityElement(type: .camera, name: "Camera", promptBlock: "wide shot")

        // Provided in wrong order
        let result = composer.compose(scene: scene, elements: [camera, style, character])

        // Expected order: Scene, Character, Style, Camera
        XCTAssertEqual(result.prompt, "A man walking, a man, cinematic, wide shot")
    }
}
