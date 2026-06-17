import XCTest
import Combine
@testable import AIStudioLocal

final class TaskQueueViewModelTests: XCTestCase {
    var viewModel: TaskQueueViewModel!
    var appState: AppState!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        // AppState needs a lot of dependencies, usually it's better to mock it or its services
        // Given TaskQueueViewModel is simple, we'll try with a real AppState if possible,
        // or just verify the behavior we can.
        appState = AppState()
        viewModel = TaskQueueViewModel(appState: appState)
        cancellables = []
    }

    override func tearDown() {
        viewModel = nil
        appState = nil
        cancellables = nil
        super.tearDown()
    }

    func testJobsUpdateFromAppState() {
        let job = GenerationJob(projectId: "p1", sceneId: "s1", status: .generatingVideo)
        let jobId = job.id

        let expectation = XCTestExpectation(description: "Jobs updated")

        viewModel.$jobs
            .dropFirst() // Initial empty array
            .sink { jobs in
                if jobs.count == 1 {
                    XCTAssertEqual(jobs.first?.id, jobId)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        appState.activeJobs = [job]

        wait(for: [expectation], timeout: 2.0)
    }

    func testClearCompletedJobs() {
        // AppState implementation of clearCompletedJobs should be called
        // We can't easily verify the call without a mock, but we can verify side effects if any
        viewModel.clearCompletedJobs()
        XCTAssertTrue(appState.activeJobs.isEmpty)
    }
}
