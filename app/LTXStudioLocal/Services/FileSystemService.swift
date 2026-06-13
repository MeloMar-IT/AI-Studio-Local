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
        return appSupport.appendingPathComponent("LTX Studio Local")
    }

    /// Returns the recommended Movies directory for exports.
    public func getMoviesDirectory() -> URL {
        let paths = fileManager.urls(for: .moviesDirectory, in: .userDomainMask)
        let movies = paths.first ?? URL(fileURLWithPath: "~/Movies").resolvingSymlinksInPath()
        return movies.appendingPathComponent("LTX Studio Local/Exports")
    }

    /// Returns the recommended Documents directory for projects.
    public func getDocumentsDirectory() -> URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docs = paths.first ?? URL(fileURLWithPath: "~/Documents").resolvingSymlinksInPath()
        return docs.appendingPathComponent("LTX Studio Local/Projects")
    }

    /// Returns the default worker script path based on the app bundle or project structure.
    public func getDefaultWorkerScriptPath() -> String {
        // In development, we look for the scripts folder relative to the project root
        // This is a heuristic for Junie environment and local dev
        let possiblePaths = [
            "../../../scripts/run-worker.sh",
            "../../scripts/run-worker.sh",
            "scripts/run-worker.sh"
        ]

        let currentPath = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        for path in possiblePaths {
            let fullPath = currentPath.appendingPathComponent(path).path
            if fileManager.fileExists(atPath: fullPath) {
                return fullPath
            }
        }

        // Fallback to a placeholder
        return "/usr/local/bin/run-ltx-worker.sh"
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
