import XCTest
@testable import AIStudioLocal

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

        // Order: Character, Location, Scene Prompt (Elements first)
        XCTAssertEqual(result.prompt, "wearing a grey hoodie, in a modern office, A man walking")
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

        // Expected order: Character, Style, Location, Camera, Audio, Scene
        let expected = "a man, cinematic, in Tokyo, wide shot, lounge music, A man"
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

        XCTAssertEqual(result.prompt, "cinematic, A beautiful sunset")
        XCTAssertEqual(result.negativePrompt, "blur, low quality")
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

    func testElementEnforcementOverride() {
        let scene = Scene(name: "Test Scene", prompt: "A woman running")
        let character = ContinuityElement(
            id: "char-1",
            type: .character,
            name: "Marcel",
            promptBlock: "Senior SRE Marcel with a beard"
        )

        let result = composer.compose(scene: scene, elements: [character])

        // Element (Marcel) should come before scene description (A woman running)
        // This ensures the model treats the character identity as the primary subject.
        XCTAssertTrue(result.prompt.hasPrefix("Senior SRE Marcel with a beard"))
        XCTAssertEqual(result.prompt, "Senior SRE Marcel with a beard, A woman running")
    }

    func testComposeWithReferenceImages() {
        let scene = Scene(name: "Test Scene", prompt: "A man walking")
        let asset1 = ContinuityAsset(path: "/path/to/img1.jpg", type: "image")
        let asset2 = ContinuityAsset(path: "/path/to/img2.png", type: "png")
        let character = ContinuityElement(
            id: "char-1",
            type: .character,
            name: "Marcel",
            promptBlock: "wearing a grey hoodie",
            assets: [asset1, asset2]
        )

        let result = composer.compose(scene: scene, elements: [character])

        // Verify image paths are collected
        XCTAssertEqual(result.referenceImagePaths.count, 2)
        XCTAssertTrue(result.referenceImagePaths.contains("/path/to/img1.jpg"))
        XCTAssertTrue(result.referenceImagePaths.contains("/path/to/img2.png"))

        // Verify enforcement instruction is added to prompt
        XCTAssertTrue(result.prompt.contains("follow the visual style and identity from the reference images strictly"))
        XCTAssertTrue(result.prompt.hasPrefix("follow the visual style and identity from the reference images strictly"))
    }

    func testComposeWithLoRA() {
        let scene = Scene(name: "Test Scene", prompt: "A man walking")
        let character = ContinuityElement(
            id: "char-1",
            type: .character,
            name: "Marcel",
            promptBlock: "wearing a grey hoodie",
            trainedLoraPath: "/path/to/marcel.safetensors"
        )

        let result = composer.compose(scene: scene, elements: [character])

        XCTAssertEqual(result.loras.count, 1)
        XCTAssertEqual(result.loras[0].path, "/path/to/marcel.safetensors")
        XCTAssertEqual(result.loras[0].scale, 1.0)
        XCTAssertEqual(result.metadata["lora_char-1"], "/path/to/marcel.safetensors")
    }
}
