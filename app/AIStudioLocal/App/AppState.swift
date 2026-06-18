import Foundation
import Combine
import OSLog

class AppState: ObservableObject {
    private let logger = Logger(subsystem: "com.ai-studio-local.app", category: "State")
    @Published var isLoading: Bool = false
    @Published var activeError: AppError?
    @Published var isWorkerAvailable: Bool = false
    @Published var workerVersion: String = ""
    @Published var workerStatus: WorkerStatus = .stopped
    @Published var workerLogs: String = ""

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
    private let workerManager: WorkerManagerProtocol
    private let environment: AppEnvironment
    private var pollingTimer: Timer?
    private var healthCheckTask: Task<Void, Never>?
    private var jobSubscriptions: [String: Task<Void, Never>] = [:]
    private var cancellables = Set<AnyCancellable>()

    private static func determineEnvironment() -> AppEnvironment {
        if let envVar = ProcessInfo.processInfo.environment["LTX_APP_ENVIRONMENT"],
           let env = AppEnvironment(rawValue: envVar.lowercased()) {
            return env
        }
        return UserSettings.shared.appEnvironment
    }

    init(
        hardwareProfiler: HardwareProfilerProtocol = HardwareProfiler(),
        generationClient: GenerationClient? = nil,
        workerManager: WorkerManagerProtocol = WorkerManager(),
        environment: AppEnvironment = determineEnvironment()
    ) {
        NSLog("🔧 AppState: init started (env: \(environment.rawValue))")
        self.environment = environment

        // Enforcement: Production mode rejects mock services
        if environment.isProduction {
            #if DEBUG
            if hardwareProfiler is MockHardwareProfiler {
                let msg = "❌ PRODUCTION SECURITY VIOLATION: MockHardwareProfiler injected in production mode"
                self.validationError = msg
                // In debug builds we can just set the error, but in release we MUST crash
                NSLog(msg)
            }
            #endif
            // Add other mock checks here as they are implemented
        }

        self.hardwareProfiler = hardwareProfiler
        self.workerManager = workerManager

        let client = generationClient ?? HTTPGenerationClient(baseURL: UserSettings.shared.workerBaseURL)
        self.generationClient = client

        setupWorkerObservers()

        Task {
            let profile = await hardwareProfiler.getHardwareProfile()
            await MainActor.run {
                self.hardwareProfile = profile
            }
            await checkWorkerHealth()

            // Auto-start worker if it's not available after initial health check
            if !self.isWorkerAvailable && UserSettings.shared.isLocalModeEnabled {
                NSLog("🚀 AppState: Worker not available on launch, starting it...")
                await startWorker()
            }
        }

        startPolling()
        setupSettingsObservers()
    }

    private func setupWorkerObservers() {
        workerManager.statusPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.workerStatus = status
                if status == .starting {
                    self?.startHealthCheckLoop()
                } else if status == .running {
                    self?.healthCheckTask?.cancel()
                    self?.healthCheckTask = nil
                } else if status == .stopped || status == .failed {
                    self?.healthCheckTask?.cancel()
                    self?.healthCheckTask = nil
                    self?.isWorkerAvailable = false
                }
            }
            .store(in: &cancellables)

        workerManager.logsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] logs in
                self?.workerLogs = logs
            }
            .store(in: &cancellables)
    }

    public func startWorker() async {
        NSLog("🚀 AppState: startWorker() called")
        do {
            try await workerManager.startWorker()
            NSLog("✅ AppState: startWorker() request sent to WorkerManager")
        } catch {
            NSLog("❌ AppState: Failed to start worker: \(error.localizedDescription)")
            await MainActor.run {
                self.activeError = AppError(
                    title: "Failed to Start Worker",
                    message: error.localizedDescription,
                    suggestedActions: ["Check worker script path in Settings", "Open Setup Instructions"]
                )
            }
        }
    }

    public func stopWorker() {
        workerManager.stopWorker()
    }

    public func stopWorkerSync() {
        workerManager.stopWorker()
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

    private func startHealthCheckLoop() {
        healthCheckTask?.cancel()
        healthCheckTask = Task {
            var attempts = 0
            let maxAttempts = 30 // 30 seconds total

            while attempts < maxAttempts && !Task.isCancelled {
                attempts += 1
                NSLog("🏥 AppState: Checking worker health (attempt \(attempts)/\(maxAttempts))...")

                do {
                    let health = try await generationClient.checkHealth()
                    NSLog("✅ AppState: Worker is online. Version: \(health.version)")
                    await MainActor.run {
                        self.isWorkerAvailable = true
                        self.workerVersion = health.version
                        self.workerStatus = .running

                        // Clear any worker-related errors
                        if let error = self.activeError, error.title == "Worker Unavailable" || error.title == "Failed to Start Worker" {
                            self.activeError = nil
                        }
                    }
                    return // Success, exit loop
                } catch {
                    // Only log every 5 attempts to avoid log spam, or if it's the last attempt
                    if attempts % 5 == 0 || attempts == maxAttempts {
                        NSLog("⏳ AppState: Worker health check attempt \(attempts) failed: \(error.localizedDescription)")
                    }

                    if attempts < maxAttempts {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                    }
                }
            }

            if !Task.isCancelled {
                await MainActor.run {
                    self.workerStatus = .failed
                    self.activeError = AppError(
                        title: "Worker Failed to Start",
                        message: "The worker process started but did not respond to health checks within 30 seconds.",
                        suggestedActions: ["Check worker logs", "Restart the application"]
                    )
                }
            }
        }
    }

    func checkWorkerHealth() async {
        if workerStatus == .starting {
            startHealthCheckLoop()
            return
        }

        NSLog("🏥 AppState: Checking worker health...")
        do {
            let health = try await generationClient.checkHealth()
            NSLog("✅ AppState: Worker is online. Version: \(health.version)")
            await MainActor.run {
                self.isWorkerAvailable = true
                self.workerVersion = health.version
                if self.workerStatus == .stopped {
                    self.workerStatus = .running
                }
                // Clear any worker-related errors if we successfully connected
                if let error = self.activeError, error.title == "Worker Unavailable" {
                    self.activeError = nil
                }
            }
        } catch {
            NSLog("❌ AppState: Worker health check failed: \(error.localizedDescription)")
            await MainActor.run {
                self.isWorkerAvailable = false

                // If the worker is stopped and local mode is enabled, try to start it
                if self.workerStatus == .stopped && UserSettings.shared.isLocalModeEnabled {
                    NSLog("🔄 AppState: Worker is stopped, attempting to restart...")
                    Task {
                        await self.startWorker()
                    }
                    return
                }

                // If the worker is still starting or stopped, don't show an error yet
                if self.workerStatus == .starting || self.workerStatus == .stopped {
                    return
                }

                if self.workerStatus == .running {
                    self.workerStatus = .stopped
                }
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
                            self.activeJobs[index].message = event.message

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
                AppLogger.shared.error("Error in job subscription for \(jobId): \(error)", category: .worker)
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
                AppLogger.shared.error("Failed to cancel job: \(error)", category: .worker)
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
                    AppLogger.shared.error("Error polling job \(job.id): \(error)", category: .worker)
                }
            }
        }
    }
}

extension NSNotification.Name {
    static let generationCompleted = NSNotification.Name("generationCompleted")
    static let modelsUpdated = NSNotification.Name("modelsUpdated")
}
