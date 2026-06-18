import XCTest
@testable import AIStudioLocal

final class EnvironmentBoundaryTests: XCTestCase {

    func testProductionModeRejectsMockHardwareProfiler() {
        let mockProfiler = MockHardwareProfiler()

        // We set DEBUG=1 in tests, so it should set validationError instead of crashing
        let appState = AppState(hardwareProfiler: mockProfiler, environment: .production)

        XCTAssertNotNil(appState.validationError)
        XCTAssertTrue(appState.validationError?.contains("PRODUCTION SECURITY VIOLATION") == true)

        XCTAssertTrue(AppEnvironment.production.isProduction)
        XCTAssertFalse(AppEnvironment.development.isProduction)
        XCTAssertFalse(AppEnvironment.test.isProduction)
    }

    func testDevelopmentModeAllowsMockHardwareProfiler() {
        let mockProfiler = MockHardwareProfiler()
        let appState = AppState(hardwareProfiler: mockProfiler, environment: .development)
        XCTAssertNotNil(appState)
    }

    func testTestModeAllowsMockHardwareProfiler() {
        let mockProfiler = MockHardwareProfiler()
        let appState = AppState(hardwareProfiler: mockProfiler, environment: .test)
        XCTAssertNotNil(appState)
    }
}
