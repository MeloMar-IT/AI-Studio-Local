import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        SettingsContentView(viewModel: SettingsViewModel(appState: appState))
    }
}

struct SettingsContentView: View {
    @StateObject var viewModel: SettingsViewModel
    @ObservedObject var settings: UserSettings

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.settings = viewModel.settings
    }

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
                            viewModel.selectFile(for: \.workerScriptPath)
                        }
                    }
                }

                HStack {
                    Text("Process Status:")
                    Spacer()
                    StatusBadge(
                        label: viewModel.workerStatus.rawValue.capitalized,
                        color: viewModel.workerStatus == .running ? .green : (viewModel.workerStatus == .starting ? .orange : .red)
                    )
                }

                HStack {
                    Text("API Status:")
                    Spacer()
                    if viewModel.isWorkerAvailable {
                        StatusBadge(label: "Connected", color: .green)
                    } else {
                        StatusBadge(label: "Disconnected", color: .red)
                    }
                }

                if viewModel.workerStatus == .stopped || viewModel.workerStatus == .failed {
                    Button("Start Worker") {
                        Task {
                            await viewModel.startWorker()
                        }
                    }
                } else if viewModel.workerStatus == .running {
                    Button("Stop Worker", role: .destructive) {
                        viewModel.stopWorker()
                    }
                }

                if !viewModel.workerVersion.isEmpty {
                    LabeledContent("Worker Version", value: viewModel.workerVersion)
                }
            }

            Section(header: Text("Storage Locations")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Storage")
                        .font(.subheadline)
                    HStack {
                        TextField("Projects Path", text: $settings.projectsDirectory)
                        Button("Select...") {
                            viewModel.selectFolder(for: \.projectsDirectory)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Continuity Library")
                        .font(.subheadline)
                    HStack {
                        TextField("Library Path", text: $settings.continuityLibraryDirectory)
                        Button("Select...") {
                            viewModel.selectFolder(for: \.continuityLibraryDirectory)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Models Folder")
                        .font(.subheadline)
                    HStack {
                        TextField("Models Path", text: $settings.modelsDirectory)
                        Button("Select...") {
                            viewModel.selectFolder(for: \.modelsDirectory)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Export Folder")
                        .font(.subheadline)
                    HStack {
                        TextField("Export Path", text: $settings.exportDirectory)
                        Button("Select...") {
                            viewModel.selectFolder(for: \.exportDirectory)
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
}
