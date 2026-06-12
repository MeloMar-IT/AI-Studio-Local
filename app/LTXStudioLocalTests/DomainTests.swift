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
        let scene = Scene.mock
        let data = try encoder.encode(scene)
        let decoded = try decoder.decode(Scene.self, from: data)
        XCTAssertEqual(scene.id, decoded.id)
        XCTAssertEqual(scene.name, decoded.name)
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
}
