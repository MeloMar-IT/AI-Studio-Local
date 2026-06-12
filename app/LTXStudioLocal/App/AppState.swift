import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isWorkerAvailable: Bool = false
    @Published var workerVersion: String = ""

    // Mock data indicators
    @Published var isModelLoaded: Bool = false
    @Published var activeJobs: [GenerationJob] = []
    @Published var activeJobsCount: Int = 0

    // Hardware Profile
    @Published var hardwareProfile: HardwareProfile = .unknown

    private let hardwareProfiler: HardwareProfilerProtocol
    private let generationClient: GenerationClient
    private var pollingTimer: Timer?

    init(
        hardwareProfiler: HardwareProfilerProtocol = HardwareProfiler(),
        generationClient: GenerationClient = HTTPGenerationClient()
    ) {
        self.hardwareProfiler = hardwareProfiler
        self.generationClient = generationClient

        Task {
            let profile = await hardwareProfiler.getHardwareProfile()
            await MainActor.run {
                self.hardwareProfile = profile
            }
            await checkWorkerHealth()
        }

        startPolling()
    }

    func checkWorkerHealth() async {
        do {
            let health = try await generationClient.checkHealth()
            await MainActor.run {
                self.isWorkerAvailable = true
                self.workerVersion = health.version
            }
        } catch {
            await MainActor.run {
                self.isWorkerAvailable = false
                self.errorMessage = "Worker is unavailable. Please make sure the Python worker is running."
            }
        }
    }

    func addJob(_ job: GenerationJob) {
        DispatchQueue.main.async {
            self.activeJobs.append(job)
            self.activeJobsCount = self.activeJobs.filter { $0.status != .completed && $0.status != .failed && $0.status != .cancelled }.count
        }
    }

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollJobs()
        }
    }

    private func pollJobs() {
        let jobsToPoll = activeJobs.filter { $0.status != .completed && $0.status != .failed && $0.status != .cancelled }

        for job in jobsToPoll {
            Task {
                do {
                    let updatedJob = try await generationClient.getJobStatus(jobId: job.id)
                    await MainActor.run {
                        if let index = self.activeJobs.firstIndex(where: { $0.id == job.id }) {
                            self.activeJobs[index] = updatedJob
                            self.activeJobsCount = self.activeJobs.filter { $0.status != .completed && $0.status != .failed && $0.status != .cancelled }.count

                            if updatedJob.status == .completed {
                                // In a real app, we might want to notify the ProjectStore or Scene here
                                NotificationCenter.default.post(name: .generationCompleted, object: updatedJob)
                            }
                        }
                    }
                } catch {
                    print("Error polling job \(job.id): \(error)")
                }
            }
        }
    }
}

extension NSNotification.Name {
    static let generationCompleted = NSNotification.Name("generationCompleted")
}
