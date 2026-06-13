import XCTest
@testable import LTXStudioLocal

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
        let project = Project.mock
        let data = try encoder.encode(project)
        let decoded = try decoder.decode(Project.self, from: data)
        XCTAssertEqual(project.id, decoded.id)
        XCTAssertEqual(project.name, decoded.name)
        XCTAssertEqual(project.aspectRatio, decoded.aspectRatio)
        XCTAssertEqual(project.timeline.clips.count, decoded.timeline.clips.count)
    }

    func testSceneEncodingDecoding() throws {
        var scene = Scene.mock
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
        let element = ContinuityElement.mock(type: .character, name: "Marcel")
        let data = try encoder.encode(element)
        let decoded = try decoder.decode(ContinuityElement.self, from: data)
        XCTAssertEqual(element.id, decoded.id)
        XCTAssertEqual(element.type, decoded.type)
        XCTAssertEqual(element.name, decoded.name)
    }

    func testGenerationJobEncodingDecoding() throws {
        let job = GenerationJob.mock
        let data = try encoder.encode(job)
        let decoded = try decoder.decode(GenerationJob.self, from: data)
        XCTAssertEqual(job.id, decoded.id)
        XCTAssertEqual(job.status, decoded.status)
        XCTAssertEqual(job.modelProfile?.id, decoded.modelProfile?.id)
    }

    func testModelProfileEncodingDecoding() throws {
        let profile = ModelProfile.mock
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
        let generation = SceneGeneration.mock
        let data = try encoder.encode(generation)
        let decoded = try decoder.decode(SceneGeneration.self, from: data)

        XCTAssertEqual(generation.id, decoded.id)
        XCTAssertEqual(generation.sceneId, decoded.sceneId)
        XCTAssertEqual(generation.outputPath, decoded.outputPath)
        XCTAssertEqual(generation.previewImagePath, decoded.previewImagePath)
        XCTAssertEqual(generation.metadataPath, decoded.metadataPath)
    }
}
