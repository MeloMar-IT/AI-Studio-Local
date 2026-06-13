import Foundation
import Combine
import OSLog

class AppState: ObservableObject {
    private let logger = Logger(subsystem: "com.ai-studio-local.app", category: "State")
    @Published var isLoading: Bool = false
    @Published var activeError: AppError?
    @Published var isWorkerAvailable: Bool = false
    @Published var workerVersion: String = ""

    // Mock data indicators
    @Published var isModelLoaded: Bool = false
    @Published var activeJobs: [GenerationJob] = []
    @Published var activeJobsCount: Int = 0

    // Injection validation error for testing
    var validationError: String? = nil

    // Hardware Profile
    @Published var hardwareProfile: HardwareProfile = .unknown

    // Continuity Library Cache for UI
    @Published var continuityElements: [ContinuityElement] = []

    private let hardwareProfiler: HardwareProfilerProtocol
    private let generationClient: GenerationClient
    private let environment: AppEnvironment
    private var pollingTimer: Timer?
    private var jobSubscriptions: [String: Task<Void, Never>] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(
        hardwareProfiler: HardwareProfilerProtocol = HardwareProfiler(),
        generationClient: GenerationClient? = nil,
        environment: AppEnvironment = UserSettings.shared.appEnvironment
    ) {
        NSLog("🔧 AppState: init started (env: \(environment.rawValue))")
        self.environment = environment

        // Enforcement: Production mode rejects mock services
        if environment.isProduction {
            if hardwareProfiler is MockHardwareProfiler {
                let msg = "❌ PRODUCTION SECURITY VIOLATION: MockHardwareProfiler injected in production mode"
                self.validationError = msg
                #if DEBUG
                // In debug builds we can just set the error, but in release we MUST crash
                NSLog(msg)
                #else
                fatalError(msg)
                #endif
            }
            // Add other mock checks here as they are implemented
        }

        self.hardwareProfiler = hardwareProfiler

        let client = generationClient ?? HTTPGenerationClient(baseURL: UserSettings.shared.workerBaseURL)
        self.generationClient = client

        Task {
            let profile = await hardwareProfiler.getHardwareProfile()
            await MainActor.run {
                self.hardwareProfile = profile
            }
            await checkWorkerHealth()
        }

        startPolling()
        setupSettingsObservers()
    }

    private func setupSettingsObservers() {
        UserSettings.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                if let newURL = URL(string: UserSettings.shared.workerURL),
                   let httpClient = self?.generationClient as? HTTPGenerationClient {
                    httpClient.updateBaseURL(newURL)
                }
                Task {
                    await self?.checkWorkerHealth()
                }
            }
            .store(in: &cancellables)
    }

    func checkWorkerHealth() async {
        NSLog("🏥 AppState: Checking worker health...")
        do {
            let health = try await generationClient.checkHealth()
            NSLog("✅ AppState: Worker is online. Version: \(health.version)")
            await MainActor.run {
                self.isWorkerAvailable = true
                self.workerVersion = health.version
            }
        } catch {
            NSLog("❌ AppState: Worker health check failed: \(error.localizedDescription)")
            await MainActor.run {
                self.isWorkerAvailable = false
                self.activeError = AppError.workerUnavailable(error: error)
            }
        }
    }

    func showError(_ error: AppError) {
        DispatchQueue.main.async {
            self.activeError = error
        }
    }

    func addJob(_ job: GenerationJob) {
        DispatchQueue.main.async {
            self.activeJobs.append(job)
            self.updateActiveJobsCount()
            self.subscribeToJob(jobId: job.id)
        }
    }

    private func subscribeToJob(jobId: String) {
        guard jobSubscriptions[jobId] == nil else { return }

        let task = Task {
            do {
                for try await event in generationClient.subscribeToJob(jobId: jobId) {
                    await MainActor.run {
                        if let index = self.activeJobs.firstIndex(where: { $0.id == jobId }) {
                            self.activeJobs[index].status = JobStatus(rawValue: event.stage) ?? self.activeJobs[index].status
                            self.activeJobs[index].progress = event.percentage ?? self.activeJobs[index].progress
                            // We don't have a direct 'message' field in GenerationJob but we could add it if needed
                            // For now we just update status and progress

                            if self.activeJobs[index].status == .completed ||
                               self.activeJobs[index].status == .failed ||
                               self.activeJobs[index].status == .cancelled {
                                self.activeJobs[index].completedAt = Date()
                                self.updateActiveJobsCount()
                                if self.activeJobs[index].status == .completed {
                                    NotificationCenter.default.post(name: .generationCompleted, object: self.activeJobs[index])
                                }
                                self.jobSubscriptions[jobId]?.cancel()
                                self.jobSubscriptions.removeValue(forKey: jobId)
                            }
                        }
                    }
                }
            } catch {
                print("Error in job subscription for \(jobId): \(error)")
                // Fallback to polling if SSE fails
                self.jobSubscriptions.removeValue(forKey: jobId)
            }
        }
        jobSubscriptions[jobId] = task
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
            for job in self.activeJobs where job.status == .completed || job.status == .failed || job.status == .cancelled {
                self.jobSubscriptions[job.id]?.cancel()
                self.jobSubscriptions.removeValue(forKey: job.id)
            }
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
        let jobsToPoll = activeJobs.filter {
            $0.status != .completed &&
            $0.status != .failed &&
            $0.status != .cancelled &&
            self.jobSubscriptions[$0.id] == nil // Only poll if not subscribed
        }

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
