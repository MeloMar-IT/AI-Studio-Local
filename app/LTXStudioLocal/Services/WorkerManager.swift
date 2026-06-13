import Foundation
import Combine
import OSLog

public enum WorkerStatus: String, Codable, Equatable {
    case stopped
    case starting
    case running
    case failed
}

public protocol WorkerManagerProtocol {
    var status: WorkerStatus { get }
    var statusPublisher: Published<WorkerStatus>.Publisher { get }
    var logs: String { get }
    var logsPublisher: Published<String>.Publisher { get }

    func startWorker() async throws
    func stopWorker()
    func clearLogs()
}

public final class WorkerManager: WorkerManagerProtocol, ObservableObject {
    private let logger = Logger(subsystem: "com.ai-studio-local.app", category: "WorkerManager")

    @Published public private(set) var status: WorkerStatus = .stopped
    public var statusPublisher: Published<WorkerStatus>.Publisher { $status }

    @Published public private(set) var logs: String = ""
    public var logsPublisher: Published<String>.Publisher { $logs }

    private var process: Process?
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupPipeObservers()
    }

    public func startWorker() async throws {
        guard status != .running && status != .starting else { return }

        await MainActor.run {
            self.status = .starting
            self.appendLog("Starting worker process...")
        }

        let scriptPath = UserSettings.shared.workerScriptPath

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            await MainActor.run {
                self.status = .failed
                self.appendLog("Error: Worker script not found at \(scriptPath)")
            }
            throw WorkerManagerError.scriptNotFound(path: scriptPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]

        // Use pipes for output and error
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Set environment variables if needed
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        process.environment = env

        process.terminationHandler = { [weak self] process in
            Task {
                await self?.handleTermination(process)
            }
        }

        do {
            try process.run()
            self.process = process
            // We don't set status to .running here, we wait for health check from AppState
            // but for UI responsiveness we can assume it's starting.
            logger.info("Worker process started with PID: \(process.processIdentifier)")
        } catch {
            await MainActor.run {
                self.status = .failed
                self.appendLog("Failed to launch process: \(error.localizedDescription)")
            }
            throw error
        }
    }

    public func stopWorker() {
        process?.terminate()
        process = nil
        status = .stopped
        appendLog("Worker process stopped.")
    }

    public func clearLogs() {
        logs = ""
    }

    private func setupPipeObservers() {
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                Task { @MainActor in
                    self?.appendLog(line)
                }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                Task { @MainActor in
                    self?.appendLog("ERROR: \(line)")
                }
            }
        }
    }

    private func handleTermination(_ process: Process) async {
        await MainActor.run {
            self.status = .stopped
            self.appendLog("Worker process terminated with status: \(process.terminationStatus)")
            self.process = nil
        }
    }

    private func appendLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)"
        if !logs.isEmpty && !logs.hasSuffix("\n") {
            logs += "\n"
        }
        logs += entry

        // Keep logs within reasonable size (last 10000 characters)
        if logs.count > 10000 {
            logs = String(logs.suffix(10000))
        }
    }
}

public enum WorkerManagerError: LocalizedError {
    case scriptNotFound(path: String)

    public var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path):
            return "Worker script not found at path: \(path)"
        }
    }
}
