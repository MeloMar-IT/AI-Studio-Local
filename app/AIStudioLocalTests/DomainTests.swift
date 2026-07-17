import XCTest
@testable import AIStudioLocal

final class DomainTests: XCTestCase {

    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testProjectEncodingDecoding() throws {
        let project = Project(
            name: "Cyberpunk Short Film",
            aspectRatio: "21:9",
            scenes: ["scene-001", "scene-002"],
            timeline: Timeline(clips: [
                TimelineClip(sceneId: "scene-001", startTime: 0, duration: 5.0),
                TimelineClip(sceneId: "scene-002", startTime: 5.0, duration: 3.5)
            ])
        )
        let data = try encoder.encode(project)
        let decoded = try decoder.decode(Project.self, from: data)
        XCTAssertEqual(project.id, decoded.id)
        XCTAssertEqual(project.name, decoded.name)
        XCTAssertEqual(project.aspectRatio, decoded.aspectRatio)
        XCTAssertEqual(project.timeline.clips.count, decoded.timeline.clips.count)
    }

    func testSceneEncodingDecoding() throws {
        var scene = Scene(
            name: "Introduction Scene",
            prompt: "A man walking through a futuristic city",
            durationSeconds: 5.0,
            attachedContinuityElements: [
                AttachedContinuityElement(elementId: "mock-char-1", type: .character),
                AttachedContinuityElement(elementId: "mock-loc-1", type: .location)
            ]
        )
        scene.mode = .imageToVideo
        scene.referenceImagePath = "/path/to/image.jpg"

        let data = try encoder.encode(scene)
        let decoded = try decoder.decode(Scene.self, from: data)

        XCTAssertEqual(scene.id, decoded.id)
        XCTAssertEqual(scene.name, decoded.name)
        XCTAssertEqual(scene.mode, decoded.mode)
        XCTAssertEqual(scene.referenceImagePath, decoded.referenceImagePath)
        XCTAssertEqual(scene.attachedContinuityElements.count, decoded.attachedContinuityElements.count)
    }

    func testContinuityElementEncodingDecoding() throws {
        let element = ContinuityElement(
            type: .character,
            name: "Marcel",
            promptBlock: "A description for Marcel",
            tags: ["mock", "character"]
        )
        let data = try encoder.encode(element)
        let decoded = try decoder.decode(ContinuityElement.self, from: data)
        XCTAssertEqual(element.id, decoded.id)
        XCTAssertEqual(element.type, decoded.type)
        XCTAssertEqual(element.name, decoded.name)
    }

    func testGenerationJobEncodingDecoding() throws {
        let job = GenerationJob(
            projectId: "mock-project",
            sceneId: "mock-scene",
            status: .generatingVideo,
            modelProfile: ModelProfileSummary(id: "fast-draft", name: "Fast Draft"),
            progress: 0.45
        )
        let data = try encoder.encode(job)
        let decoded = try decoder.decode(GenerationJob.self, from: data)
        XCTAssertEqual(job.id, decoded.id)
        XCTAssertEqual(job.status, decoded.status)
        XCTAssertEqual(job.modelProfile?.id, decoded.modelProfile?.id)
    }

    func testModelProfileEncodingDecoding() throws {
        let profile = ModelProfile(
            id: "ltx-2.3-distilled",
            name: "LTX-2.3 Distilled",
            description: "Fast draft generation",
            family: .ltxVideo,
            version: "2.3",
            expectedFiles: ["ltx_video_2.3_distilled.safetensors", "config.json"],
            memoryRequirementGB: 16,
            supportedModes: ["text-to-video", "image-to-video"],
            recommendedHardware: "Apple M1 Pro 16GB or better",
            installed: true,
            recommended: true,
            status: "installed"
        )
        let data = try encoder.encode(profile)
        let decoded = try decoder.decode(ModelProfile.self, from: data)
        XCTAssertEqual(profile.id, decoded.id)
        XCTAssertEqual(profile.modelFamily, decoded.modelFamily)
        XCTAssertEqual(profile.qualityLevel, decoded.qualityLevel)
    }

    func testBrandKitSync() throws {
        var brandKit = BrandKit(name: "Test Brand", promptBlock: "Original Prompt")
        brandKit.introCardText = "Hello World"
        brandKit.brandColors = ["#FF0000"]
        brandKit.syncElement()

        XCTAssertTrue(brandKit.element.promptBlock.contains("introCardText"))
        XCTAssertTrue(brandKit.element.promptBlock.contains("Hello World"))

        let restoredKit = BrandKit(element: brandKit.element)
        XCTAssertEqual(restoredKit.introCardText, "Hello World")
        XCTAssertEqual(restoredKit.brandColors, ["#FF0000"])
    }

    func testProjectTemplates() throws {
        let templates = ProjectTemplate.defaultTemplates
        XCTAssertEqual(templates.count, 3)

        let linkedin = templates.first { $0.id == "linkedin-sre-explainer" }
        XCTAssertNotNil(linkedin)
        XCTAssertEqual(linkedin?.aspectRatio, "4:5")
        XCTAssertEqual(linkedin?.sceneStructures.count, 5)

        let youtube = templates.first { $0.id == "youtube-tech-intro" }
        XCTAssertNotNil(youtube)
        XCTAssertEqual(youtube?.aspectRatio, "16:9")
        XCTAssertEqual(youtube?.sceneStructures.count, 4)

        let book = templates.first { $0.id == "book-promo-video" }
        XCTAssertNotNil(book)
        XCTAssertEqual(book?.aspectRatio, "9:16")
        XCTAssertEqual(book?.sceneStructures.count, 4)
    }
    func testSceneGenerationEncodingDecoding() throws {
        let generation = SceneGeneration(
            sceneId: "mock-scene",
            outputPath: "mock/video.mp4",
            previewImagePath: "mock/preview.jpg",
            composedPrompt: "A cinematic shot of a futuristic city with neon lights",
            negativePrompt: "blurry, low quality",
            modelProfile: ModelProfileSummary(id: "balanced", name: "Balanced"),
            seed: 12345,
            resolution: SceneResolution(width: 1920, height: 1080),
            duration: 5.0,
            createdAt: Date()
        )
        let data = try encoder.encode(generation)
        let decoded = try decoder.decode(SceneGeneration.self, from: data)

        XCTAssertEqual(generation.id, decoded.id)
        XCTAssertEqual(generation.sceneId, decoded.sceneId)
        XCTAssertEqual(generation.outputPath, decoded.outputPath)
        XCTAssertEqual(generation.previewImagePath, decoded.previewImagePath)
        XCTAssertEqual(generation.metadataPath, decoded.metadataPath)
    }
}
