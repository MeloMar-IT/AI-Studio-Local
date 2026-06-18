import XCTest
@testable import AIStudioLocal

final class UserSettingsTests: XCTestCase {
    var fileManager: FileManager!
    var tempBaseDir: URL!

    override func setUp() {
        super.setUp()
        fileManager = FileManager.default
        tempBaseDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempBaseDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? fileManager.removeItem(at: tempBaseDir)
        super.tearDown()
    }

    func testDefaultConfigCreation() {
        let settings = UserSettings.shared

        XCTAssertFalse(settings.workerURL.isEmpty)
        XCTAssertFalse(settings.projectsDirectory.isEmpty)
        XCTAssertFalse(settings.modelsDirectory.isEmpty)
        XCTAssertFalse(settings.exportDirectory.isEmpty)
        XCTAssertEqual(settings.logLevel, .info)
    }

    func testDirectoryInitialization() {
        let fs = FileSystemService(fileManager: fileManager)
        let appSupport = fs.getApplicationSupportDirectory()

        XCTAssertTrue(appSupport.path.contains("Library/Application Support/AI Studio Local"))

        let movies = fs.getMoviesDirectory()
        XCTAssertTrue(movies.path.contains("Movies/AI Studio Local/Exports"))
    }

    func testValidateDirectories() throws {
        let settings = UserSettings.shared

        // Ensure directories exist for validation
        try FileSystemService.shared.ensureDirectoryExists(at: settings.projectsURL)
        try FileSystemService.shared.ensureDirectoryExists(at: settings.continuityLibraryURL)
        try FileSystemService.shared.ensureDirectoryExists(at: settings.modelsURL)
        try FileSystemService.shared.ensureDirectoryExists(at: settings.exportURL)

        XCTAssertNoThrow(try settings.validate())
    }

    func testInvalidWorkerURL() {
        let settings = UserSettings.shared
        let originalURL = settings.workerURL

        // This is tricky because AppStorage is persistent.
        // For testing we should ideally use a mock/injectable storage,
        // but for now let's just test the validation logic if we can.

        settings.workerURL = ""
        // Wait, URL(string: "") is actually nil or empty URL depending on implementation.
        // Actually our validation checks if URL(string: workerURL) is nil.

        // Let's use a truly invalid URL
        settings.workerURL = " "

        XCTAssertThrowsError(try settings.validate())

        // Restore
        settings.workerURL = originalURL
    }
}
