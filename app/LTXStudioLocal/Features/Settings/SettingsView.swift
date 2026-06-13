import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = UserSettings.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section(header: Text("General")) {
                LabeledContent("App Version", value: "1.0.0 (MVP)")
                Toggle("Local Mode", isOn: .constant(settings.isLocalModeEnabled))
                    .disabled(true)

                Text("Local Mode: prompts, source assets and generated media stay on this Mac unless you explicitly enable an external service.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Worker Configuration")) {
                TextField("Worker URL", text: $settings.workerURL)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Worker Script Path")
                        .font(.subheadline)
                    HStack {
                        TextField("Script Path", text: $settings.workerScriptPath)
                        Button("Select...") {
                            selectFile { path in
                                settings.workerScriptPath = path
                            }
                        }
                    }
                }

                HStack {
                    Text("Process Status:")
                    Spacer()
                    StatusBadge(
                        label: appState.workerStatus.rawValue.capitalized,
                        color: appState.workerStatus == .running ? .green : (appState.workerStatus == .starting ? .orange : .red)
                    )
                }

                HStack {
                    Text("API Status:")
                    Spacer()
                    if appState.isWorkerAvailable {
                        StatusBadge(label: "Connected", color: .green)
                    } else {
                        StatusBadge(label: "Disconnected", color: .red)
                    }
                }

                if appState.workerStatus == .stopped || appState.workerStatus == .failed {
                    Button("Start Worker") {
                        Task {
                            await appState.startWorker()
                        }
                    }
                } else if appState.workerStatus == .running {
                    Button("Stop Worker", role: .destructive) {
                        appState.stopWorker()
                    }
                }

                if !appState.workerVersion.isEmpty {
                    LabeledContent("Worker Version", value: appState.workerVersion)
                }
            }

            Section(header: Text("Storage Locations")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Storage")
                        .font(.subheadline)
                    HStack {
                        TextField("Projects Path", text: $settings.projectsDirectory)
                        Button("Select...") {
                            selectFolder { path in
                                settings.projectsDirectory = path
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Continuity Library")
                        .font(.subheadline)
                    HStack {
                        TextField("Library Path", text: $settings.continuityLibraryDirectory)
                        Button("Select...") {
                            selectFolder { path in
                                settings.continuityLibraryDirectory = path
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Models Folder")
                        .font(.subheadline)
                    HStack {
                        TextField("Models Path", text: $settings.modelsDirectory)
                        Button("Select...") {
                            selectFolder { path in
                                settings.modelsDirectory = path
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Export Folder")
                        .font(.subheadline)
                    HStack {
                        TextField("Export Path", text: $settings.exportDirectory)
                        Button("Select...") {
                            selectFolder { path in
                                settings.exportDirectory = path
                            }
                        }
                    }
                }
            }

            Section(header: Text("Privacy & External Services")) {
                Toggle("Cloud Fallback (Disabled)", isOn: .constant(false))
                    .disabled(true)

                Text("Telemetry: No data is being collected. If telemetry is ever added later, it will be strictly opt-in.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Appearance")) {
                Text("Theme: Dark (Locked)")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectFolder(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK {
            if let url = panel.url {
                completion(url.path)
            }
        }
    }

    private func selectFile(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            if let url = panel.url {
                completion(url.path)
            }
        }
    }
}
