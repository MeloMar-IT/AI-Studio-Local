import Foundation
import SwiftUI
import OSLog

public final class UserSettings: ObservableObject {
    private let logger = Logger(subsystem: "com.ai-studio-local.app", category: "Settings")
    public static let shared = UserSettings()

    @AppStorage("workerURL") public var workerURL: String = "http://localhost:8000"
    @AppStorage("projectsDirectory") public var projectsDirectory: String = ""
    @AppStorage("continuityLibraryDirectory") public var continuityLibraryDirectory: String = ""
    @AppStorage("modelsDirectory") public var modelsDirectory: String = ""
    @AppStorage("exportDirectory") public var exportDirectory: String = ""
    @AppStorage("isLocalModeEnabled") public var isLocalModeEnabled: Bool = true
    @AppStorage("isCloudFallbackEnabled") public var isCloudFallbackEnabled: Bool = false
    @AppStorage("appEnvironment") public var appEnvironment: AppEnvironment = .development

    private init() {
        NSLog("⚙️ UserSettings: init started")
        setupDefaultDirectories()
        NSLog("⚙️ UserSettings: init completed")
    }

    private func setupDefaultDirectories() {
        let fileManager = FileManager.default

        if projectsDirectory.isEmpty {
            if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                projectsDirectory = documents.appendingPathComponent("AI Studio Projects").path
            } else {
                NSLog("⚠️ UserSettings: Could not find document directory")
                // Fallback to home directory
                projectsDirectory = (NSHomeDirectory() as NSString).appendingPathComponent("Documents/AI Studio Projects")
            }
        }

        if continuityLibraryDirectory.isEmpty {
            if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                continuityLibraryDirectory = appSupport.appendingPathComponent("AI Studio Local/ContinuityLibrary").path
            } else {
                NSLog("⚠️ UserSettings: Could not find application support directory")
                continuityLibraryDirectory = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/AI Studio Local/ContinuityLibrary")
            }
        }

        if modelsDirectory.isEmpty {
            if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                modelsDirectory = appSupport.appendingPathComponent("AI Studio Local/Models").path
            } else {
                NSLog("⚠️ UserSettings: Could not find application support directory for models")
                modelsDirectory = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/AI Studio Local/Models")
            }
        }

        if exportDirectory.isEmpty {
            if let movies = fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first {
                exportDirectory = movies.appendingPathComponent("AI Studio Exports").path
            } else {
                NSLog("⚠️ UserSettings: Could not find movies directory")
                exportDirectory = (NSHomeDirectory() as NSString).appendingPathComponent("Movies/AI Studio Exports")
            }
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
