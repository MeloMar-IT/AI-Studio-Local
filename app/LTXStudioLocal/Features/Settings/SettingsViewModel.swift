import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    @Published var settings: UserSettings
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(settings: UserSettings = .shared, appState: AppState) {
        self.settings = settings
        self.appState = appState

        // Settings are already ObservableObject, but we might want to listen to changes
        // and trigger validations or worker restarts if needed.
    }

    var workerStatus: WorkerStatus {
        appState.workerStatus
    }

    var isWorkerAvailable: Bool {
        appState.isWorkerAvailable
    }

    var workerVersion: String {
        appState.workerVersion
    }

    func startWorker() async {
        await appState.startWorker()
    }

    func stopWorker() {
        appState.stopWorker()
    }

    func selectFolder(for keyPath: ReferenceWritableKeyPath<UserSettings, String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK {
            if let url = panel.url {
                settings[keyPath: keyPath] = url.path
            }
        }
    }

    func selectFile(for keyPath: ReferenceWritableKeyPath<UserSettings, String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            if let url = panel.url {
                settings[keyPath: keyPath] = url.path
            }
        }
    }
}
