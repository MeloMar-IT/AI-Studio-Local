import XCTest
import Combine
@testable import LTXStudioLocal

@MainActor
final class ModelManagerViewModelTests: XCTestCase {
    var viewModel: ModelManagerViewModel!
    var mockModelStore: MockModelStore!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockModelStore = MockModelStore()
        viewModel = ModelManagerViewModel(modelStore: mockModelStore)
        cancellables = []
    }

    override func tearDown() {
        viewModel = nil
        mockModelStore = nil
        cancellables = nil
        super.tearDown()
    }

    func testFetchModelsSuccess() async throws {
        let expectedModels = [
            ModelProfile(id: "m1", name: "Model 1", description: "Test description", family: .ltxVideo, recommended: true)
        ]
        mockModelStore.modelsToReturn = expectedModels

        viewModel.fetchModels()

        // Wait for @MainActor task to finish
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.models.count, 1)
        XCTAssertEqual(viewModel.models.first?.id, "m1")
        XCTAssertEqual(viewModel.selectedModel?.id, "m1")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testFetchModelsFailure() async throws {
        mockModelStore.shouldFail = true

        viewModel.fetchModels()

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.models.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.isOffline)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSelectModel() {
        let model = ModelProfile(id: "m2", name: "Model 2", description: "Test desc", family: .ltxVideo)
        viewModel.selectModel(model)
        XCTAssertEqual(viewModel.selectedModel?.id, "m2")
    }

    func testValidateModelFolder() async throws {
        let expectedResponse = ModelValidationResponse(
            matchedProfile: ModelProfile.mock,
            missingFiles: [],
            warnings: [],
            canUse: true,
            message: "Valid model"
        )
        mockModelStore.validationResponse = expectedResponse

        viewModel.validateModelFolder(at: "/test/path")

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(viewModel.importValidationResult)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDownloadModel() async throws {
        viewModel.downloadModel(modelId: "m1")

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.downloadJobId, "job1")
        XCTAssertFalse(viewModel.isDownloading)
    }
}

class MockModelStore: ModelStore {
    var modelsToReturn: [ModelProfile] = []
    var shouldFail = false
    var validationResponse: ModelValidationResponse?
    var importResponse: ModelImportResponse = ModelImportResponse(success: true, message: "Imported", targetPath: "/path")

    func fetchModels() async throws -> [ModelProfile] {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"]) }
        return modelsToReturn
    }

    func validateModelFolder(path: String) async throws -> ModelValidationResponse {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Validation failed"]) }
        return validationResponse ?? ModelValidationResponse(matchedProfile: nil, missingFiles: [], warnings: [], canUse: false, message: "Error")
    }

    func importModel(path: String, copy: Bool, modelId: String?) async throws -> ModelImportResponse {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Import failed"]) }
        return importResponse
    }

    func downloadModel(modelId: String) async throws -> ModelDownloadResponse {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download failed"]) }
        return ModelDownloadResponse(success: true, message: "Started", jobId: "job1", modelId: modelId)
    }
}
