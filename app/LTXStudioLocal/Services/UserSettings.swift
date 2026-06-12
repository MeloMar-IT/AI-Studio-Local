import Foundation
import SwiftUI
import OSLog

public enum LogLevel: String, Codable, CaseIterable {
    case debug
    case info
    case warning
    case error
}

public final class UserSettings: ObservableObject {
    private let logger = Logger(subsystem: "com.ai-studio-local.app", category: "Settings")
    private let fileSystem = FileSystemService.shared
    public static let shared = UserSettings()

    @AppStorage("workerURL") public var workerURL: String = "http://localhost:8000"
    @AppStorage("projectsDirectory") public var projectsDirectory: String = ""
    @AppStorage("continuityLibraryDirectory") public var continuityLibraryDirectory: String = ""
    @AppStorage("modelsDirectory") public var modelsDirectory: String = ""
    @AppStorage("exportDirectory") public var exportDirectory: String = ""
    @AppStorage("isLocalModeEnabled") public var isLocalModeEnabled: Bool = true
    @AppStorage("isCloudFallbackEnabled") public var isCloudFallbackEnabled: Bool = false
    @AppStorage("appEnvironment") public var appEnvironment: AppEnvironment = .development
    @AppStorage("logLevel") public var logLevel: LogLevel = .info
    @AppStorage("defaultGenerationProfile") public var defaultGenerationProfile: String = "ltx-2.3-distilled"

    private init() {
        NSLog("⚙️ UserSettings: init started")
        setupDefaultDirectories()
        ensureDirectoriesExist()
        NSLog("⚙️ UserSettings: init completed")
    }

    private func setupDefaultDirectories() {
        if projectsDirectory.isEmpty {
            projectsDirectory = fileSystem.getDocumentsDirectory().path
        }

        if continuityLibraryDirectory.isEmpty {
            continuityLibraryDirectory = fileSystem.getApplicationSupportDirectory().appendingPathComponent("continuity-library").path
        }

        if modelsDirectory.isEmpty {
            modelsDirectory = fileSystem.getApplicationSupportDirectory().appendingPathComponent("Models").path
        }

        if exportDirectory.isEmpty {
            exportDirectory = fileSystem.getMoviesDirectory().path
        }
    }

    private func ensureDirectoriesExist() {
        do {
            try fileSystem.ensureDirectoryExists(at: projectsURL)
            try fileSystem.ensureDirectoryExists(at: continuityLibraryURL)
            try fileSystem.ensureDirectoryExists(at: modelsURL)
            try fileSystem.ensureDirectoryExists(at: exportURL)
        } catch {
            NSLog("⚠️ UserSettings: Failed to ensure directories exist: \(error.localizedDescription)")
        }
    }

    public func validate() throws {
        try fileSystem.validateDirectory(at: projectsURL)
        try fileSystem.validateDirectory(at: continuityLibraryURL)
        try fileSystem.validateDirectory(at: modelsURL)
        try fileSystem.validateDirectory(at: exportURL)

        if URL(string: workerURL) == nil {
            throw FileSystemError.directoryNotFound(path: "Invalid Worker URL: \(workerURL)")
        }
    }

    public var workerBaseURL: URL {
        URL(string: workerURL) ?? URL(string: "http://localhost:8000") ?? URL(fileURLWithPath: "/")
    }

    public var projectsURL: URL {
        URL(fileURLWithPath: projectsDirectory)
    }

    public var continuityLibraryURL: URL {
        URL(fileURLWithPath: continuityLibraryDirectory)
    }

    public var modelsURL: URL {
        URL(fileURLWithPath: modelsDirectory)
    }

    public var exportURL: URL {
        URL(fileURLWithPath: exportDirectory)
    }
}
