import Foundation

public final class FileSystemService {
    public static let shared = FileSystemService()

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Ensures that a directory exists at the given URL.
    /// Creates it if it doesn't exist, including intermediate directories.
    public func ensureDirectoryExists(at url: URL) throws {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                throw FileSystemError.pathExistsButIsNotDirectory(path: url.path)
            }
        } else {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Validates if a directory exists and is writable.
    public func validateDirectory(at url: URL) throws {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw FileSystemError.directoryNotFound(path: url.path)
        }

        guard fileManager.isWritableFile(atPath: url.path) else {
            throw FileSystemError.directoryNotWritable(path: url.path)
        }
    }

    /// Returns the recommended Application Support directory for the app.
    public func getApplicationSupportDirectory() -> URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths.first ?? URL(fileURLWithPath: "~/Library/Application Support").resolvingSymlinksInPath()
        return appSupport.appendingPathComponent("AI Studio Local")
    }

    /// Returns the recommended Movies directory for exports.
    public func getMoviesDirectory() -> URL {
        let paths = fileManager.urls(for: .moviesDirectory, in: .userDomainMask)
        let movies = paths.first ?? URL(fileURLWithPath: "~/Movies").resolvingSymlinksInPath()
        return movies.appendingPathComponent("AI Studio Local/Exports")
    }

    /// Returns the recommended Documents directory for projects.
    public func getDocumentsDirectory() -> URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docs = paths.first ?? URL(fileURLWithPath: "~/Documents").resolvingSymlinksInPath()
        return docs.appendingPathComponent("AI Studio Local/Projects")
    }

    /// Returns the default worker script path based on the app bundle or project structure.
    public func getDefaultWorkerScriptPath() -> String {
        let bundlePath = Bundle.main.bundlePath
        let currentDir = fileManager.currentDirectoryPath

        // NSLog is noisy in tests, but helpful for debugging real app startup
        // NSLog("📂 FileSystemService: Bundle path: \(bundlePath)")
        // NSLog("📂 FileSystemService: Current directory: \(currentDir)")

        // Check if the script exists at the given relative paths
        let scriptRelativePath = "scripts/run-worker.sh"

        // Try searching upwards from current directory and bundle path
        var searchRoots = [currentDir, bundlePath]

        // Add home directory as a possible search root if we are in a dev environment
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        searchRoots.append(homeDir)

        for root in searchRoots {
            var currentURL = URL(fileURLWithPath: root)
            // Search up to 5 levels up
            for _ in 0..<5 {
                let scriptURL = currentURL.appendingPathComponent(scriptRelativePath)
                if fileManager.fileExists(atPath: scriptURL.path) {
                    NSLog("✅ FileSystemService: Found worker script at: \(scriptURL.path)")
                    return scriptURL.path
                }

                let parentURL = currentURL.deletingLastPathComponent()
                if parentURL == currentURL { break } // Reached root
                currentURL = parentURL
            }
        }

        NSLog("📂 FileSystemService: Bundle path: \(bundlePath)")
        NSLog("📂 FileSystemService: Current directory: \(currentDir)")

        // Fallback to searching at specific relative depths (legacy support)
        let possiblePaths = [
            "../../../scripts/run-worker.sh",
            "../../scripts/run-worker.sh",
            "../scripts/run-worker.sh",
            "scripts/run-worker.sh",
            "./scripts/run-worker.sh"
        ]

        for path in possiblePaths {
            // Check relative to current directory
            let pathFromCurrent = URL(fileURLWithPath: currentDir).appendingPathComponent(path).path
            if fileManager.fileExists(atPath: pathFromCurrent) {
                NSLog("✅ FileSystemService: Found worker script at (relative to current): \(pathFromCurrent)")
                return pathFromCurrent
            }

            // Check relative to bundle path
            let pathFromBundle = URL(fileURLWithPath: bundlePath).appendingPathComponent(path).path
            if fileManager.fileExists(atPath: pathFromBundle) {
                NSLog("✅ FileSystemService: Found worker script at (relative to bundle): \(pathFromBundle)")
                return pathFromBundle
            }
        }

        // Fallback to a placeholder
        let fallback = "/usr/local/bin/run-worker.sh"
        NSLog("⚠️ FileSystemService: Worker script not found. Falling back to: \(fallback)")
        return fallback
    }
}

public enum FileSystemError: LocalizedError {
    case directoryNotFound(path: String)
    case directoryNotWritable(path: String)
    case pathExistsButIsNotDirectory(path: String)

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found at: \(path)"
        case .directoryNotWritable(let path):
            return "Directory is not writable: \(path)"
        case .pathExistsButIsNotDirectory(let path):
            return "Path exists but is not a directory: \(path)"
        }
    }
}

extension AppError {
    public static func configurationError(error: Error) -> AppError {
        AppError(
            title: "Configuration Error",
            message: "There was a problem with the application configuration.",
            technicalDetails: error.localizedDescription,
            suggestedActions: [
                "Check your directory permissions",
                "Reset settings in the Settings panel",
                "Ensure your Library folder is accessible"
            ]
        )
    }
}
