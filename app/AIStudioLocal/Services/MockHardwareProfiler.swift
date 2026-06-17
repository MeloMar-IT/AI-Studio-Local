#if DEBUG
import Foundation

public final class MockHardwareProfiler: HardwareProfilerProtocol {
    public var mockProfile: HardwareProfile

    public init(mockProfile: HardwareProfile = .unknown) {
        self.mockProfile = mockProfile
    }

    public func getHardwareProfile() async -> HardwareProfile {
        return mockProfile
    }
}
#endif
