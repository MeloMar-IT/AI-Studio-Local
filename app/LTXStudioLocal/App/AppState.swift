import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var activeError: AppError?
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
                self.activeError = AppError.workerUnavailable(error: error)
            }
        }
    }

    func addJob(_ job: GenerationJob) {
        DispatchQueue.main.async {
            self.activeJobs.append(job)
            self.updateActiveJobsCount()
        }
    }

    func cancelJob(_ job: GenerationJob) {
        Task {
            do {
                try await generationClient.cancelJob(jobId: job.id)
                await MainActor.run {
                    if let index = self.activeJobs.firstIndex(where: { $0.id == job.id }) {
                        self.activeJobs[index].status = .cancelled
                        self.activeJobs[index].completedAt = Date()
                        self.updateActiveJobsCount()
                    }
                }
            } catch {
                print("Failed to cancel job: \(error)")
            }
        }
    }

    func clearCompletedJobs() {
        DispatchQueue.main.async {
            self.activeJobs.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
            self.updateActiveJobsCount()
        }
    }

    private func updateActiveJobsCount() {
        self.activeJobsCount = self.activeJobs.filter { $0.status != .completed && $0.status != .failed && $0.status != .cancelled }.count
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
                            var updatedJobWithLocalData = updatedJob
                            // Preserve local data if worker doesn't return it
                            updatedJobWithLocalData.sceneName = updatedJob.sceneName ?? self.activeJobs[index].sceneName
                            updatedJobWithLocalData.startedAt = updatedJob.startedAt ?? self.activeJobs[index].startedAt

                            if updatedJob.status == .completed || updatedJob.status == .failed || updatedJob.status == .cancelled {
                                updatedJobWithLocalData.completedAt = updatedJob.completedAt ?? Date()
                            }

                            self.activeJobs[index] = updatedJobWithLocalData
                            self.updateActiveJobsCount()

                            if updatedJob.status == .completed {
                                // In a real app, we might want to notify the ProjectStore or Scene here
                                NotificationCenter.default.post(name: .generationCompleted, object: updatedJobWithLocalData)
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
