import XCTest
@testable import LTXStudioLocal

final class PromptImprovementHelperTests: XCTestCase {
    var helper: PromptImprovementHelper!

    override func setUp() {
        super.setUp()
        helper = DefaultPromptImprovementHelper()
    }

    func testEmptyPrompt() {
        let result = helper.improve("")
        XCTAssertTrue(result.improved.isEmpty)
        XCTAssertTrue(result.changes.isEmpty)
    }

    func testBasicEnrichment() {
        let prompt = "A cat sitting"
        let result = helper.improve(prompt)

        XCTAssertEqual(result.original, prompt)
        XCTAssertTrue(result.improved.contains("Subject: A cat"))
        XCTAssertTrue(result.improved.contains("Action: sitting"))
        XCTAssertTrue(result.improved.contains("Environment:"))
        XCTAssertTrue(result.improved.contains("Camera:"))
        XCTAssertTrue(result.improved.contains("Lighting:"))
        XCTAssertTrue(result.improved.contains("Mood:"))
        XCTAssertTrue(result.improved.contains("Audio:"))

        XCTAssertEqual(result.changes["Subject"], "A cat")
        XCTAssertEqual(result.changes["Action"], "sitting")
    }

    func testCityKeywords() {
        let prompt = "Man in the city"
        let result = helper.improve(prompt)

        XCTAssertTrue(result.improved.contains("cityscape"))
        XCTAssertTrue(result.improved.contains("neon"))
        XCTAssertEqual(result.changes["Environment"], "bustling futuristic cityscape with neon reflections")
    }

    func testForestKeywords() {
        let prompt = "Woman in a forest"
        let result = helper.improve(prompt)

        XCTAssertTrue(result.improved.contains("forest"))
        XCTAssertTrue(result.improved.contains("trees"))
        XCTAssertEqual(result.changes["Environment"], "lush ancient forest with giant moss-covered trees")
    }

    func testMovementKeywords() {
        let prompt = "Car running fast"
        let result = helper.improve(prompt)

        XCTAssertTrue(result.improved.contains("tracking shot"))
        XCTAssertEqual(result.changes["Camera"], "dynamic tracking shot following the movement")
    }

    func testPortraitKeywords() {
        let prompt = "Close up of a face looking at camera"
        let result = helper.improve(prompt)

        XCTAssertTrue(result.improved.contains("zoom into a close-up"))
        XCTAssertTrue(result.improved.contains("rim lighting"))
        XCTAssertEqual(result.changes["Camera"], "slow dramatic zoom into a close-up")
    }
}
