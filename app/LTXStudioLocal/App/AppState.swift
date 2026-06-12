import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Mock data indicators
    @Published var isModelLoaded: Bool = false
    @Published var activeJobsCount: Int = 0

    // Hardware Profile
    @Published var hardwareProfile: HardwareProfile = .unknown

    private let hardwareProfiler: HardwareProfilerProtocol

    init(hardwareProfiler: HardwareProfilerProtocol = HardwareProfiler()) {
        self.hardwareProfiler = hardwareProfiler

        Task {
            let profile = await hardwareProfiler.getHardwareProfile()
            await MainActor.run {
                self.hardwareProfile = profile
            }
        }
    }
}
