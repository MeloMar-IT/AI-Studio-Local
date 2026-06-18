import Foundation
import OSLog

/// A centralized logging service for the application
public final class AppLogger {
    public static let shared = AppLogger()

    private let subsystem = "com.ai-studio-local.app"

    public let lifecycle = Logger(subsystem: "com.ai-studio-local.app", category: "Lifecycle")
    public let appState = Logger(subsystem: "com.ai-studio-local.app", category: "AppState")
    public let ui = Logger(subsystem: "com.ai-studio-local.app", category: "UI")
    public let service = Logger(subsystem: "com.ai-studio-local.app", category: "Service")
    public let network = Logger(subsystem: "com.ai-studio-local.app", category: "Network")
    public let project = Logger(subsystem: "com.ai-studio-local.app", category: "Project")
    public let worker = Logger(subsystem: "com.ai-studio-local.app", category: "Worker")

    private let logFileURL: URL? = {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let logDir = appSupport?.appendingPathComponent("AI Studio Local/logs")

        // Try to find the project root if running in dev
        // For production, it might be better to use Application Support
        // But the requirement is "1 log files", usually implying a shared location.
        // Let's try to find the project logs folder first, fallback to App Support.

        let currentDir = fileManager.currentDirectoryPath
        var searchURL = URL(fileURLWithPath: currentDir)
        for _ in 0..<5 {
            let potentialLogDir = searchURL.appendingPathComponent("logs")
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: potentialLogDir.path, isDirectory: &isDir), isDir.boolValue {
                return potentialLogDir.appendingPathComponent("ai-studio-local.log")
            }
            let parentURL = searchURL.deletingLastPathComponent()
            if parentURL == searchURL { break }
            searchURL = parentURL
        }

        if let logDir = logDir {
            try? fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)
            return logDir.appendingPathComponent("ai-studio-local.log")
        }
        return nil
    }()

    private let fileQueue = DispatchQueue(label: "com.ai-studio-local.app.logger.file", qos: .utility)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss,SSS"
        return formatter
    }()

    private init() {
        if let path = logFileURL?.path {
            print("[AppLogger] Logging to file: \(path)")
        }
    }

    /// Log a message with a specific category and level
    public func log(_ message: String, category: LoggerCategory = .general, level: OSLogType = .default) {
        let logger = getLogger(for: category)
        logger.log(level: level, "\(message)")

        // Write to file
        writeToFile(message, category: category, level: level)

        // Also print to console for development visibility if needed
        #if DEBUG
        let prefix = "[\(category.rawValue.uppercased())]"
        print("\(prefix) \(message)")
        #endif
    }

    private func writeToFile(_ message: String, category: LoggerCategory, level: OSLogType) {
        guard let logFileURL = logFileURL else { return }

        let timestamp = dateFormatter.string(from: Date())
        let levelStr = levelString(for: level)
        let categoryStr = category.rawValue.uppercased()
        let logLine = "\(timestamp) - app.\(categoryStr) - \(levelStr) - \(message)\n"

        fileQueue.async {
            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            }

            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                if let data = logLine.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            }
        }
    }

    private func levelString(for level: OSLogType) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .error: return "ERROR"
        case .fault: return "CRITICAL"
        default: return "INFO"
        }
    }

    public func debug(_ message: String, category: LoggerCategory = .general) {
        log(message, category: category, level: .debug)
    }

    public func info(_ message: String, category: LoggerCategory = .general) {
        log(message, category: category, level: .info)
    }

    public func error(_ message: String, category: LoggerCategory = .general) {
        log(message, category: category, level: .error)
    }

    public func fault(_ message: String, category: LoggerCategory = .general) {
        log(message, category: category, level: .fault)
    }

    private func getLogger(for category: LoggerCategory) -> Logger {
        switch category {
        case .lifecycle: return lifecycle
        case .appState: return appState
        case .ui: return ui
        case .service: return service
        case .network: return network
        case .project: return project
        case .worker: return worker
        case .general: return Logger(subsystem: subsystem, category: "General")
        }
    }
}

public enum LoggerCategory: String {
    case general
    case lifecycle
    case appState
    case ui
    case service
    case network
    case project
    case worker
}
