import XCTest
@testable import LTXStudioLocal

final class AppErrorTests: XCTestCase {

    func testWorkerUnavailableMapping() {
        let error = GenerationClientError.workerUnavailable(nil)
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "Worker Unavailable")
        XCTAssertTrue(appError.message.contains("local AI worker is not responding"))
    }

    func testInsufficientMemoryMapping() {
        let error = GenerationClientError.workerError(code: "insufficient_memory", message: "Out of memory", action: nil)
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "Insufficient Memory")
        XCTAssertEqual(appError.documentationURL?.absoluteString, "https://docs.ltx.local/memory-optimization")
    }

    func testMlxMissingMapping() {
        let error = GenerationClientError.workerError(code: "mlx_missing", message: "MLX not found", action: nil)
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "MLX Not Found")
        XCTAssertEqual(appError.documentationURL?.absoluteString, "https://docs.ltx.local/setup")
    }

    func testFfmpegMissingMapping() {
        let error = GenerationClientError.workerError(code: "ffmpeg_missing", message: "ffmpeg not found", action: nil)
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "FFmpeg Not Found")
        XCTAssertEqual(appError.documentationURL?.absoluteString, "https://docs.ltx.local/dependencies")
    }

    func testUnsupportedMacMapping() {
        let error = GenerationClientError.workerError(code: "unsupported_mac", message: "Intel not supported", action: nil)
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "Unsupported Mac")
        XCTAssertTrue(appError.message.contains("Intel not supported"))
    }

    func testMissingModelMapping() {
        let error = GenerationClientError.missingModel("ltx-video-v1")
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "Model Not Installed")
        XCTAssertTrue(appError.message.contains("ltx-video-v1"))
    }

    func testUnsupportedCapabilityMapping() {
        let error = GenerationClientError.unsupportedCapability("audio-to-video")
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "Generation Not Supported")
        XCTAssertTrue(appError.technicalDetails?.contains("audio-to-video") ?? false)
    }

    func testGenerationCancelledMapping() {
        let error = GenerationClientError.workerError(code: "generation_cancelled", message: "User cancelled", action: nil)
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "Generation Cancelled")
    }

    func testProjectCorruptMapping() {
        let error = ProjectStoreError.invalidProjectFolder
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "Project Load Failed")
    }

    func testMissingContinuityElementMapping() {
        let error = ProjectStoreError.missingContinuityElement(name: "Marcel", type: "Character")
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "Missing Continuity Element")
        XCTAssertTrue(appError.message.contains("Character 'Marcel'"))
    }

    func testMissingMediaFileMapping() {
        let error = ProjectStoreError.missingMediaFile(path: "/path/to/video.mp4")
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "Missing Media File")
        XCTAssertTrue(appError.message.contains("/path/to/video.mp4"))
    }

    func testExportFailedMapping() {
        let error = ExportError.fileSystemError(NSError(domain: "test", code: 1, userInfo: nil))
        let appError = error.asAppError

        XCTAssertEqual(appError.title, "Export Failed")
    }
}
