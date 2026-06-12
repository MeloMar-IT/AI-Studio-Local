import Foundation
import SwiftUI

public final class UserSettings: ObservableObject {
    public static let shared = UserSettings()

    @AppStorage("workerURL") public var workerURL: String = "http://localhost:8000"
    @AppStorage("projectsDirectory") public var projectsDirectory: String = ""
    @AppStorage("continuityLibraryDirectory") public var continuityLibraryDirectory: String = ""
    @AppStorage("modelsDirectory") public var modelsDirectory: String = ""
    @AppStorage("exportDirectory") public var exportDirectory: String = ""
    @AppStorage("isLocalModeEnabled") public var isLocalModeEnabled: Bool = true
    @AppStorage("isCloudFallbackEnabled") public var isCloudFallbackEnabled: Bool = false

    private init() {
        setupDefaultDirectories()
    }

    private func setupDefaultDirectories() {
        let fileManager = FileManager.default

        if projectsDirectory.isEmpty {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            projectsDirectory = documents.appendingPathComponent("AI Studio Projects").path
        }

        if continuityLibraryDirectory.isEmpty {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            continuityLibraryDirectory = appSupport.appendingPathComponent("AI Studio Local/ContinuityLibrary").path
        }

        if modelsDirectory.isEmpty {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            modelsDirectory = appSupport.appendingPathComponent("AI Studio Local/Models").path
        }

        if exportDirectory.isEmpty {
            let movies = fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first!
            exportDirectory = movies.appendingPathComponent("AI Studio Exports").path
        }
    }

    public var workerBaseURL: URL {
        URL(string: workerURL) ?? URL(string: "http://localhost:8000")!
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
