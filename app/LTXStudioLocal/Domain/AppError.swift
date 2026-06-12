import Foundation

/// A user-facing error model that separates presentation from technical details.
public struct AppError: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let message: String
    public let technicalDetails: String?
    public let suggestedActions: [String]
    public let retryAction: (() -> Void)?

    public init(
        id: UUID = UUID(),
        title: String,
        message: String,
        technicalDetails: String? = nil,
        suggestedActions: [String] = [],
        retryAction: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.technicalDetails = technicalDetails
        self.suggestedActions = suggestedActions
        self.retryAction = retryAction
    }

    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}

extension AppError {
    public static func workerUnavailable(error: Error? = nil) -> AppError {
        AppError(
            title: "Worker Unavailable",
            message: "The local AI worker is not responding. Please ensure the Python worker is running.",
            technicalDetails: error?.localizedDescription,
            suggestedActions: [
                "Run 'make run-worker' in your terminal",
                "Check if any other service is using port 8000",
                "Ensure your Python environment is correctly set up"
            ]
        )
    }

    public static func modelNotInstalled(modelName: String) -> AppError {
        AppError(
            title: "Model Not Installed",
            message: "The required model '\(modelName)' is not found on your system.",
            suggestedActions: [
                "Open Model Manager to download the model",
                "Check your model storage path in Settings"
            ]
        )
    }

    public static func unsupportedMac(reason: String) -> AppError {
        AppError(
            title: "Unsupported Mac",
            message: "Your Mac does not meet the minimum requirements for local video generation. \(reason)",
            suggestedActions: [
                "This app requires Apple Silicon (M1, M2, M3, M4)",
                "A minimum of 16GB Unified Memory is recommended"
            ]
        )
    }

    public static func insufficientMemory() -> AppError {
        AppError(
            title: "Insufficient Memory",
            message: "This generation needs more memory than your Mac currently has available.",
            suggestedActions: [
                "Try using Fast Draft mode",
                "Lower the resolution to 720p or less",
                "Reduce the duration of the clip",
                "Close other memory-heavy applications"
            ]
        )
    }

    public static func generationFailed(details: String? = nil, retry: (() -> Void)? = nil) -> AppError {
        AppError(
            title: "Generation Failed",
            message: "Something went wrong during the generation process.",
            technicalDetails: details,
            suggestedActions: [
                "Check the worker logs for more details",
                "Try a different seed or shorter duration"
            ],
            retryAction: retry
        )
    }

    public static func exportFailed(error: Error? = nil) -> AppError {
        AppError(
            title: "Export Failed",
            message: "We couldn't export your video. Please check if you have enough disk space.",
            technicalDetails: error?.localizedDescription,
            suggestedActions: [
                "Ensure the destination folder is writable",
                "Check available disk space",
                "Try a different export preset"
            ]
        )
    }

    public static func projectLoadFailed(error: Error? = nil) -> AppError {
        AppError(
            title: "Project Load Failed",
            message: "This project folder appears to be corrupted or was created with an incompatible version.",
            technicalDetails: error?.localizedDescription,
            suggestedActions: [
                "Select a valid .ltxproject folder",
                "Check if project.json is missing",
                "Ensure you have permission to read the folder"
            ]
        )
    }

    public static func projectSaveFailed(error: Error? = nil) -> AppError {
        AppError(
            title: "Project Save Failed",
            message: "We couldn't save your project changes.",
            technicalDetails: error?.localizedDescription,
            suggestedActions: [
                "Check if the disk is full",
                "Ensure you have permission to write to the folder",
                "Try 'Save As' to a different location"
            ]
        )
    }
}
